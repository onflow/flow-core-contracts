import "RandomBeaconHistory"

transaction(randomSource: [UInt8]) {
    prepare(acct: AuthAccount) {
        let heartbeat = acct.borrow<&RandomBeaconHistory.Heartbeat>(
            from: RandomBeaconHistory.HeartbeatStoragePath
        ) ?? panic("Could not borrow heartbeat resource")

        heartbeat.heartbeat(randomSourceHistory: randomSource)
    }
}
