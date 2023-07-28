pub contract SourceOfRandomnessHistory {

    /// Canonical storage path for the SourceOfRandomnessHistory.Heartbeat resource.
    pub let HeartbeatStoragePath: StoragePath

    pub resource Heartbeat {
        pub fun heartbeat(randomSourceHistory: [UInt8]) {
            // called every block in the system transaction
        }
    }

    init() {
        self.HeartbeatStoragePath = /storage/FlowSourceOfRandomnessHistoryHeartbeat

        self.account.save(<-create Heartbeat(), to: self.HeartbeatStoragePath)
    }
}