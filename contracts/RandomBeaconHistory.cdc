/// RandomBeaconHistory (FLIP 123)
///
/// This contract stores the history of random sources generated by the Flow network. The defined Heartbeat resource is
/// updated by the Flow Service Account at the end of every block with that block's source of randomness.
///
/// While the source values are safely generated by the Random Beacon (non-predictable, unbiasable, verifiable) and transmitted into the execution 
/// environment via the committing transaction, using the raw values from this contract does not guarantee non-revertible
/// randomness. The Hearbeat is intended to be used in conjunction with a
/// commit-reveal mechanism to provide an onchain source of non-revertible randomness.
// It is also recommended to use the source values with a pseudo-random number 
// generator (PRNG) to generate an arbitrary-long sequence of random values. 
// 
// For usage of randomness where result abortion is not an issue, it is recommended
// to use the Cadence built-in function `revertibleRandom`, which is also based on 
// the safe Random Beacon. 
///
/// Read the full FLIP here: https://github.com/onflow/flips/pull/123
///
access(all) contract RandomBeaconHistory {

    /// The height at which the first source of randomness was recorded
    access(contract) var lowestHeight: UInt64?
    /// Sequence of random sources recorded by the Heartbeat, stored as an array over a mapping to reduce storage
    access(contract) let randomSourceHistory: [[UInt8]]

    /// The path of the Heartbeat resource in the deployment account
    access(all) let HeartbeatStoragePath: StoragePath

    /* --- Hearbeat --- */
    //
    /// The Heartbeat resource containing each block's source of randomness in sequence
    ///
    access(all) resource Heartbeat {

        /// Callable by owner of the Heartbeat resource, Flow Service Account, records the provided random source
        ///
        /// @param randomSourceHistory The random source to record
        ///
        access(all) fun heartbeat(randomSourceHistory: [UInt8]) {

            let currentBlockHeight = getCurrentBlock().height
            if RandomBeaconHistory.lowestHeight == nil {
                RandomBeaconHistory.lowestHeight = currentBlockHeight
            }

            RandomBeaconHistory.randomSourceHistory.append(randomSourceHistory)
        }
    }

    /// Getter for the source of randomness at a given block height. Panics if the requested block height either
    /// precedes or exceeds the recorded history. Note that a source of randomness for block n will not be accessible
    /// until block n+1.
    ///
    /// @param atBlockHeight The block height at which to retrieve the source of randomness
    /// @return The source of randomness at the given block height
    ///
    access(all) fun sourceOfRandomness(atBlockHeight: UInt64): [UInt8] {
        pre {
            self.lowestHeight != nil: "History has not yet been initialized"
            atBlockHeight >= self.lowestHeight!: "Requested block height precedes recorded history"
            atBlockHeight < getCurrentBlock().height: "Source of randomness not yet recorded"
        }
        let index: UInt64 = atBlockHeight - self.lowestHeight!

        assert(
            index >= 0 && index < UInt64(self.randomSourceHistory.length),
            message: "Problem finding random source history index"
        )

        return self.randomSourceHistory[index]
    }

    /// Getter for the totality of recorded randomness source history
    ///
    /// @return An array of random sources, each source an array of UInt8
    ///
    access(all) view fun getRandomSourceHistory(): [[UInt8]] {
        return self.lowestHeight != nil ? self.randomSourceHistory : panic("History has not yet been initialized")
    }

    /// Getter for the block height at which the first source of randomness was recorded
    ///
    /// @return The block height at which the first source of randomness was recorded
    ///
    access(all) view fun getlowestHeight(): UInt64 {
        return self.lowestHeight ?? panic("History has not yet been initialized")
    }

    init() {
        self.lowestHeight = nil
        self.randomSourceHistory = []
        self.HeartbeatStoragePath = /storage/FlowRandomBeaconHistoryHeartbeat

        self.account.save(<-create Heartbeat(), to: self.HeartbeatStoragePath)
    }
}
