import XCTest
@testable import AudioEngineClientLive
import AudioEngineClient
import AudioKit
import Foundation
/*
final class AudioEngineClientTest: XCTestCase {
    
    func testResourcePaths() {
        print("=== Resource Path Debug ===")
        
        // Test Bundle.main
        print("Bundle.main.bundlePath: \(Bundle.main.bundlePath)")
        
        // Try to find preset file
        let presetURL1 = Bundle.main.url(forResource: "drumpad-presets-550", withExtension: "json", subdirectory: "Presets")
        print("Bundle.main preset with subdirectory: \(presetURL1?.path ?? "nil")")
        
        let presetURL2 = Bundle.main.url(forResource: "drumpad-presets-550", withExtension: "json")
        print("Bundle.main preset without subdirectory: \(presetURL2?.path ?? "nil")")
        
        // Try to find sample file
        let sampleURL1 = Bundle.main.url(forResource: "01", withExtension: "wav", subdirectory: "Samples")
        print("Bundle.main sample with subdirectory: \(sampleURL1?.path ?? "nil")")
        
        let sampleURL2 = Bundle.main.url(forResource: "01", withExtension: "wav")
        print("Bundle.main sample without subdirectory: \(sampleURL2?.path ?? "nil")")
        
        // Test Bundle.module
        let presetModuleURL1 = Bundle.module.url(forResource: "drumpad-presets-550", withExtension: "json", subdirectory: "Presets")
        print("Bundle.module preset with subdirectory: \(presetModuleURL1?.path ?? "nil")")
        
        let presetModuleURL2 = Bundle.module.url(forResource: "drumpad-presets-550", withExtension: "json")
        print("Bundle.module preset without subdirectory: \(presetModuleURL2?.path ?? "nil")")
        
        // Try to find sample file in module
        let sampleModuleURL1 = Bundle.module.url(forResource: "01", withExtension: "wav", subdirectory: "Samples")
        print("Bundle.module sample with subdirectory: \(sampleModuleURL1?.path ?? "nil")")
        
        let sampleModuleURL2 = Bundle.module.url(forResource: "01", withExtension: "wav")
        print("Bundle.module sample without subdirectory: \(sampleModuleURL2?.path ?? "nil")")
        
        // List all resources in main bundle
        print("Main bundle resource URLs:")
        let resourceUrls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        for url in resourceUrls {
            print("  \(url.path)")
        }
        
        print("Main bundle resource URLs in Presets subdirectory:")
        let presetUrls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Presets") ?? []
        for url in presetUrls {
            print("  \(url.path)")
        }
        
        print("Main bundle WAV resource URLs:")
        let wavUrls = Bundle.main.urls(forResourcesWithExtension: "wav", subdirectory: nil) ?? []
        for url in wavUrls {
            print("  \(url.path)")
        }
        
        print("Main bundle WAV resource URLs in Samples subdirectory:")
        let sampleUrls = Bundle.main.urls(forResourcesWithExtension: "wav", subdirectory: "Samples") ?? []
        for url in sampleUrls {
            print("  \(url.path)")
        }
        
        print("=========================")
    }
    
    func testAudioEngineInitialization() async throws {
        // Test that the audio engine can be initialized
        let audioEngine = AudioEngineClient.liveValue
        
        XCTAssertNotNil(audioEngine)
        
        // Test loading a preset
        do {
            try await audioEngine.loadPreset("550")
            print("Successfully loaded preset 550")
            
            let isLoaded = await audioEngine.isPresetLoaded()
            XCTAssertTrue(isLoaded)
            
            let samples = await audioEngine.loadedSamples()
            print("Loaded \(samples.count) samples")
            
            let pads = await audioEngine.drumPads()
            print("Loaded \(pads.count) drum pads")
            
            // Test playing a pad if samples are loaded
            if !pads.isEmpty {
                let firstPadId = pads.first!.key
                try await audioEngine.playPad(firstPadId)
                print("Played pad with ID: \(firstPadId)")
            }
        } catch {
            XCTFail("Failed to load preset: \(error)")
        }
    }
}
*/
