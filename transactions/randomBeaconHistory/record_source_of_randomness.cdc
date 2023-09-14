import "RandomBeaconHistory"

/// Commits the source of randomness for the requested block height from the RandomBeaconHistory Heartbeat
///
// TODO: Replace transaction parameter with randomSourceHistory() call
transaction(sor: [UInt8]) {
    prepare(serviceAccount: AuthAccount) {
        // Borrow the RandomBeaconHistory.Heartbeat Resource from the signing service account
        let randomBeaconHistoryHeartbeat = serviceAccount.borrow<&RandomBeaconHistory.Heartbeat>(
                from: RandomBeaconHistory.HeartbeatStoragePath
            ) ?? panic("Couldn't borrow RandomBeaconHistory.Heartbeat Resource")
        
        // TODO
        // let sor: [UInt8] = randomSourceHistory()
        
        // Commit the source of randomness at the current blockheight
        randomBeaconHistoryHeartbeat.heartbeat(randomSourceHistory: sor)
    }
}