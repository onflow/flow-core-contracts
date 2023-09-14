import "RandomBeaconHistory"

/// Retrieves the source of randomness for the requested block height from the RandomBeaconHistory Heartbeat
///
pub fun main(atBlockHeight: UInt64): [UInt8] {
    // Get the account storing the heartbeat
    let heartbeatAccount = getAccount(RandomBeaconHistory.getRandomBeaconHistoryAddress())
    // Borrow the HeartbeatPublic Capability
    let randomBeaconHistoryHeartbeat = heartbeatAccount.getCapability<&{RandomBeaconHistory.HeartbeatPublic}>(
            RandomBeaconHistory.HeartbeatPublicPath
        ).borrow()
        ?? panic("Couldn't borrow RandomBeaconHistory.Heartbeat Resource")
    // Return the source of randomness for the requested block height
    return randomBeaconHistoryHeartbeat.sourceOfRandomness(atBlockHeight: atBlockHeight)
}