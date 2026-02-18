import AudioEngineClient

/// Actor for thread-safe choke group management
actor ChokeGroupManager {
    private var chokeGroupPlayers: [Int: Set<AudioEngineClient.DrumPad.ID>] = [:]
    
    /// Register a pad as playing in a choke group
    func registerPlaying(padID: AudioEngineClient.DrumPad.ID, chokeGroup: Int) {
        guard chokeGroup > 0 else { return }
        chokeGroupPlayers[chokeGroup, default: []].insert(padID)
    }
    
    /// Remove a pad from choke group tracking
    func unregister(padID: AudioEngineClient.DrumPad.ID, chokeGroup: Int) {
        guard chokeGroup > 0 else { return }
        chokeGroupPlayers[chokeGroup]?.remove(padID)
        if chokeGroupPlayers[chokeGroup]?.isEmpty == true {
            chokeGroupPlayers.removeValue(forKey: chokeGroup)
        }
    }
    
    /// Get all pads in a choke group that should be choked
    func getPadsToChoke(inGroup chokeGroup: Int, excluding padID: AudioEngineClient.DrumPad.ID) -> Set<AudioEngineClient.DrumPad.ID> {
        guard chokeGroup > 0 else { return [] }
        var pads = chokeGroupPlayers[chokeGroup] ?? []
        pads.remove(padID)
        return pads
    }
    
    /// Clear all tracking (for preset change)
    func clearAll() {
        chokeGroupPlayers.removeAll()
    }
    
    /// Clean up stale entries (pads that are no longer playing)
    func cleanupStaleEntries(activePadIDs: Set<AudioEngineClient.DrumPad.ID>) {
        for (chokeGroup, padIDs) in chokeGroupPlayers {
            let stalePadIDs = padIDs.subtracting(activePadIDs)
            for stalePadID in stalePadIDs {
                chokeGroupPlayers[chokeGroup]?.remove(stalePadID)
            }
            if chokeGroupPlayers[chokeGroup]?.isEmpty == true {
                chokeGroupPlayers.removeValue(forKey: chokeGroup)
            }
        }
    }
}
