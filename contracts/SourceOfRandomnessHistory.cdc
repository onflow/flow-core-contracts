pub contract SourceOfRandomnessHistory {

    /// Canonical storage path for the SourceOfRandomness.Heartbeat resource.
    pub let HeartbeatStoragePath: StoragePath

    pub resource Heartbeat {
        pub fun heartbeat() {
            // called every block in the system transaction

            // only callable in the system transaction and by the service account
            let blockEntropy = randomSourceHistory()
        }
    }

    init() {
        self.HeartbeatStoragePath = /storage/SourceOfRandomnessHeartbeat

        self.account.save(<-create Heartbeat(), to: self.HeartbeatStoragePath)
    }
}