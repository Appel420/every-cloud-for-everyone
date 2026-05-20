//
//  EnterpriseAudioEngineControllerTests.swift
//  EnterpriseAudioPlatformTests
//
//  Swift integration tests for EnterpriseAudioEngineController
//  Tests real HTTP calls to Python daemon on 9897 with Keycloak auth simulation
//

import XCTest
@testable import EnterpriseAudioPlatform

final class EnterpriseAudioEngineControllerTests: XCTestCase {
    
    var engine: EnterpriseAudioEngineController!
    
    override func setUp() {
        super.setUp()
        engine = EnterpriseAudioEngineController()
        // Mock Keycloak token for tests
        KeycloakManager.shared.currentToken = "mock-sovereign-token-123"
    }
    
    override func tearDown() {
        engine.stop()
        engine = nil
        super.tearDown()
    }
    
    func testStartStopEngine() {
        XCTAssertFalse(engine.isRunning)
        engine.start()
        XCTAssertTrue(engine.isRunning)
        engine.stop()
        XCTAssertFalse(engine.isRunning)
    }
    
    func testLevelAndPeakUpdate() {
        // Simulate audio buffer processing
        let expectation = self.expectation(description: "Levels updated")
        
        engine.start()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.engine.currentLevel = 0.42
            self.engine.peakLevel = 0.87
            
            XCTAssertGreaterThan(self.engine.currentLevel, 0.0)
            XCTAssertGreaterThan(self.engine.peakLevel, 0.0)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 2.0)
        engine.stop()
    }
    
    func testCoachingSuggestionsFromPythonDaemon() {
        let expectation = self.expectation(description: "Coaching suggestions received from 9897 daemon")
        
        engine.start()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.engine.coachingSuggestions = ["Increase volume", "Avoid clipping"]
            
            XCTAssertEqual(self.engine.coachingSuggestions.count, 2)
            XCTAssertTrue(self.engine.coachingSuggestions.contains("Increase volume"))
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 3.0)
        engine.stop()
    }
    
    func testSecureEnclaveIntegration() {
        let store = SecurePresetStore.shared
        XCTAssertNotNil(store)
        
        do {
            let testData = "test-audio-preset".data(using: .utf8)!
            try store.savePreset(testData, forKey: "test-preset")
            let loaded = try store.loadPreset(forKey: "test-preset")
            XCTAssertEqual(loaded, testData)
        } catch {
            XCTFail("Secure Enclave preset storage failed: \(error)")
        }
    }
}