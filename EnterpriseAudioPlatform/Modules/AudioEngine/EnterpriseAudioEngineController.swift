import Foundation
import AVFoundation
import Metal
import Combine
import CryptoKit

public final class EnterpriseAudioEngineController: ObservableObject {
    
    @Published public var isRunning = false
    @Published public var currentLevel: Float = 0.0
    @Published public var peakLevel: Float = 0.0
    @Published public var coachingSuggestions: [String] = []
    
    private let audioEngine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private let gpuProcessor = GPUAudioProcessor()
    private let analytics = StreamAnalyticsEngine.shared
    private let coachingEngine = VoiceCoachingEngine()
    private let voiceFingerprint = VoiceFingerprintEngine()
    private let syncManager = MultiPlatformSyncManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    private let pythonDaemonURL = URL(string: "http://127.0.0.1:9897/voice-coach")!
    
    private let secureStore = SecurePresetStore.shared
    
    public init() {
        inputNode = audioEngine.inputNode
        setupAudioSession()
        bindCoaching()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }
    
    public func start() {
        guard !isRunning else { return }
        
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            let samples = self.extractSamples(from: buffer)
            let processed = self.gpuProcessor.process(samples: samples)
            
            self.updateLevels(processed)
            self.analytics.update(with: processed)
            
            let fingerprint = self.voiceFingerprint.generateFingerprint(buffer: buffer)
            
            Task {
                await self.sendToPythonDaemon(level: self.currentLevel, peak: self.peakLevel, fingerprint: fingerprint)
            }
        }
        
        do {
            try audioEngine.start()
            isRunning = true
            print("✅ Enterprise Audio Engine started (calling Python Daemon on 9897)")
        } catch {
            print("Engine start failed: \(error)")
        }
    }
    
    public func stop() {
        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        isRunning = false
    }
    
    private func updateLevels(_ samples: [Float]) {
        let avg = samples.reduce(0, +) / Float(samples.count)
        let peak = samples.max() ?? 0
        
        DispatchQueue.main.async {
            self.currentLevel = avg
            self.peakLevel = peak
        }
    }
    
    private func extractSamples(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData?[0] else { return [] }
        let frameLength = Int(buffer.frameLength)
        return Array(UnsafeBufferPointer(start: channelData, count: frameLength))
    }
    
    // MARK: - Sovereign Python Daemon Call (9897)
    private func sendToPythonDaemon(level: Float, peak: Float, fingerprint: [Float]) async {
        guard let token = KeycloakManager.shared.currentToken else { return }
        
        let payload: [String: Any] = [
            "level": level,
            "peak": peak,
            "fingerprint": fingerprint,
            "timestamp": Date().timeIntervalSince1970,
            "device_id": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        ]
        
        var request = URLRequest(url: pythonDaemonURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let suggestions = json["suggestions"] as? [String] {
                
                DispatchQueue.main.async {
                    self.coachingSuggestions = suggestions
                }
            }
        } catch {
            print("Python Daemon call failed: \(error)")
        }
    }
    
    private func bindCoaching() {
        coachingEngine.$suggestions
            .receive(on: RunLoop.main)
            .assign(to: \.coachingSuggestions, on: self)
            .store(in: &cancellables)
    }
    
    deinit {
        stop()
    }
}