//
//  Live.swift
//  AudioEngineClientLive
//

import ComposableArchitecture
import AudioEngineClient
import AudioKit
import Foundation

// Test function to debug resource paths
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

extension AudioEngineClient: DependencyKey {
    public static let liveValue: AudioEngineClient = {
        // Run the test to debug resource paths
        testResourcePaths()
        
        let actor = AudioEngineActor()

        return AudioEngineClient(
            loadPreset: { presetId in
                try await actor.loadPreset(presetId: presetId)
            },
            playSample: { path in
                try await actor.playSample(at: path)
            },
            playPad: { padId in
                try await actor.playPad(padId: padId)
            },
            stopAll: {
                await actor.stopAll()
            },
            loadedSamples: {
                return await actor.loadedSamples()
            },
            drumPads: {
                return await actor.drumPads()
            },
            isPresetLoaded: {
                return await actor.isPresetLoaded()
            },
            currentPresetId: {
                return await actor.currentPresetId()
            },
            unloadPreset: {
                await actor.unloadPreset()
            },
            sampleForPad: { padId in
                return await actor.sampleForPad(padId: padId)
            }
        )
    }()
}