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
    /// Start index of the first gap in the `randomSourceHistory` array where random sources were not recorded, because
    /// of a heartbeat failure.
    /// There may be non contiguous gaps in the history, `gapStartIndex` is the start index of the lowest-height
    /// gap.
    /// If no gap exists, `gapStartIndex` is equal to the `randomSourceHistory` array length.
    access(contract) var gapStartIndex: UInt64

    /// The path of the Heartbeat resource in the deployment account
    access(all) let HeartbeatStoragePath: StoragePath


    /// back fills entries in the history array starting from the stored `gapStartIndex`,
    /// using `randomSource` as a seed for all entries.
    //
    /// all entries would use the same entropy. Each entry is extracted from `randomSource` using
    /// successive hashing. This makes sure the entries are all distinct although they provide
    /// the same entropy.
    //
    /// gaps only occur in the rare event of a system transaction failure. In this case, entries are still
    /// filled using a source not known at the time of block execution, which guaranteed unpredicatability.
    access(contract) fun backFill(randomSource: [UInt8]) {
        // maximum number of entries to back fill per transaction to limit the computation cost.
        let maxEntries = 100
        let arrayLength = UInt64(self.randomSourceHistory.length)

        var newEntry = randomSource
        var index = self.gapStartIndex
        var count = 0
        while count < maxEntries {
            // move to the next empty entry
            while index < arrayLength && self.randomSourceHistory[index] != [] {
                index = index + 1
            }
            // if we reach the end of the array then all existing gaps got filled
            if index == arrayLength {
                break
            }
            // back fill the empty entry
            newEntry = HashAlgorithm.SHA3_256.hash(newEntry)
            self.randomSourceHistory[index] = newEntry
            index = index + 1
            count = count + 1
        }
        
        // no more backfilling is possible but we need to update `gapStartIndex`
        // to the next empty index if any still exists
        while index < arrayLength && self.randomSourceHistory[index] != [] {
            index = index + 1
        }
        self.gapStartIndex = index
    }

    /* --- Hearbeat --- */
    //
    /// The Heartbeat resource containing each block's source of randomness in sequence
    ///
    access(all) resource Heartbeat {

        /// Callable by owner of the Heartbeat resource, Flow Service Account, records the provided random source
        ///
        /// @param randomSourceHistory The random source to record
        ///
        /// The Flow protocol makes sure to call this function once per block as a system call. The transaction 
        /// comes at the end of each block so that the current block's entry becomes available only in the child 
        /// block.
        ///
        access(all) fun heartbeat(randomSourceHistory: [UInt8]) { 

            let currentBlockHeight = getCurrentBlock().height
            if RandomBeaconHistory.lowestHeight == nil {
                RandomBeaconHistory.lowestHeight = currentBlockHeight
            }

            // next index to fill with the new random source
            // so that evetually randomSourceHistory[nextIndex] = inputRandom
            let nextIndex = currentBlockHeight - RandomBeaconHistory.lowestHeight!

            // find out if `gapStartIndex` needs to be updated
            if RandomBeaconHistory.gapStartIndex == UInt64(RandomBeaconHistory.randomSourceHistory.length) {
                // enter only if no gap already exists in the past history.
                // If a gap already exists, `gapStartIndex` should not be overwritten.
                if nextIndex > UInt64(RandomBeaconHistory.randomSourceHistory.length) {
                    // enter if a new gap is detected in the current transaction,
                    // i.e some past height entries were not recorded.
                    // In this case, update `gapStartIndex`
                    RandomBeaconHistory.gapStartIndex = UInt64(RandomBeaconHistory.randomSourceHistory.length)
                }
            }

            // regardless of whether `gapStartIndex` got updated or not,
            // if a new gap is detected in the current transaction, fill the gap with empty entries.
            while nextIndex > UInt64(RandomBeaconHistory.randomSourceHistory.length) {
                // this happens in the rare case when a new gap occurs due to a system chunk failure
                RandomBeaconHistory.randomSourceHistory.append([])
            }

            // we are now at the correct index to record the source of randomness
            // created by the protocol for the current block
            RandomBeaconHistory.randomSourceHistory.append(randomSourceHistory)

            // check for any existing gap and backfill using the input random source if needed.
            // If there are no gaps, `gapStartIndex` is equal to `RandomBeaconHistory`'s length.
            if RandomBeaconHistory.gapStartIndex < UInt64(RandomBeaconHistory.randomSourceHistory.length) {
                // backfilling happens in the rare case when a gap occurs due to a system chunk failure.
                // backFilling is limited to a max entries only to limit the computation cost.
                // This means a large gap may need a few transactions to get fully backfilled.
                RandomBeaconHistory.backFill(randomSource: randomSourceHistory)
            }
        }
    }

    /* --- RandomSourceHistory --- */
    //
    /// Represents a random source value for a given block height
    ///
    access(all) struct RandomSource {
        access(all) let blockHeight: UInt64
        access(all) let value: [UInt8]
    
        init(blockHeight: UInt64, value: [UInt8]) {
            self.blockHeight = blockHeight
            self.value = value
        }
    }

    /* --- RandomSourceHistoryPage --- */
    //
    /// Contains RandomSource values ordered chronologically according to associated block height
    ///
    access(all) struct RandomSourceHistoryPage {
        access(all) let page: UInt64
        access(all) let perPage: UInt64
        access(all) let totalLength: UInt64
        access(all) let values: [RandomSource]
    
        init(page: UInt64, perPage: UInt64, totalLength: UInt64, values: [RandomSource]) {
            self.page = page
            self.perPage = perPage
            self.totalLength = totalLength
            self.values = values
        }
    }

    /* --- Contract Methods --- */
    //
    /// Getter for the source of randomness at a given block height. Panics if the requested block height either
    /// precedes or exceeds the recorded history. Note that a source of randomness for block n will not be accessible
    /// until block n+1.
    ///
    /// @param atBlockHeight The block height at which to retrieve the source of randomness
    ///
    /// @return The source of randomness at the given block height as RandomSource struct
    ///
    access(all) fun sourceOfRandomness(atBlockHeight blockHeight: UInt64): RandomSource {
        pre {
            self.lowestHeight != nil: "History has not yet been initialized"
            blockHeight >= self.lowestHeight!: "Requested block height precedes recorded history"
            blockHeight < getCurrentBlock().height: "Source of randomness not yet recorded"
        }
        let index = blockHeight - self.lowestHeight!
        assert(
            index >= 0,
            message: "Problem finding random source history index"
        )
        assert(
            index < UInt64(self.randomSourceHistory.length) && self.randomSourceHistory[index] != [],
            message: "Source of randomness is currently not available but will be available soon"
        )
        return RandomSource(blockHeight: blockHeight, value: self.randomSourceHistory[index])
    }

    /// Retrieves a page from the history of random sources recorded so far, ordered chronologically
    ///
    /// @param page: The page number to retrieve, 0-indexed
    /// @param perPage: The number of random sources to include per page
    ///
    /// @return A RandomSourceHistoryPage containing RandomSource values in choronological order according to
    /// associated block height
    ///
    access(all) view fun getRandomSourceHistoryPage(_ page: UInt64, perPage: UInt64): RandomSourceHistoryPage {
        pre {
            self.lowestHeight != nil: "History has not yet been initialized"
        }
        let values: [RandomSource] = []
        let totalLength = UInt64(self.randomSourceHistory.length)

        var startIndex = page * perPage
        if startIndex > totalLength {
            startIndex = totalLength
        }
        var endIndex = startIndex + perPage
        if endIndex > totalLength {
            endIndex = totalLength
        }

        // Return empty page if request exceeds last page
        if startIndex == endIndex {
            return RandomSourceHistoryPage(page: page, perPage: perPage, totalLength: totalLength, values: values)
        }

        // Iterate over history and construct page RandomSource values
        let lowestHeight = self.lowestHeight!
        for i, value in self.randomSourceHistory.slice(from: Int(startIndex), upTo: Int(endIndex)) {
            assert(
                value != [],
                message: "Source of randomness is currently not available but will be available soon"
            )
            values.append(
                RandomSource(
                    blockHeight: lowestHeight + startIndex + UInt64(i),
                    value: value
                )
            )
        }

        return RandomSourceHistoryPage(
            page: page,
            perPage: perPage,
            totalLength: totalLength,
            values: values
        )
    }

    /// Getter for the block height at which the first source of randomness was recorded
    ///
    /// @return The block height at which the first source of randomness was recorded
    ///
    access(all) view fun getLowestHeight(): UInt64 {
        return self.lowestHeight ?? panic("History has not yet been initialized")
    }

    init() {
        self.lowestHeight = nil
        self.randomSourceHistory = []
        self.gapStartIndex = 0
        self.HeartbeatStoragePath = /storage/FlowRandomBeaconHistoryHeartbeat

        self.account.save(<-create Heartbeat(), to: self.HeartbeatStoragePath)
    }
}
