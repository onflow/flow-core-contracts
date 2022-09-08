/// This contract is used to defined block height and software version boundaries
/// for the software run by Execution Nodes.
pub contract ExecutionNodeVersionBeacon {

    /// Struct representing software version as Semantic Version
    /// along with helper functions
    /// For reference, see https://semver.org/
    pub struct Semver {
        /// Components defining a semantic version
        pub let major: UInt8
        pub let minor: UInt8
        pub let patch: UInt8
        pub let preRelease: String?

        /// Oldest compatitible version with this version
        ///
        /// Defining this can help with logic around updating before a target block is reached
        /// Such behavior may be desireable in the event breaking changes are released
        /// between versions
        pub let oldestCompatibleVersion: Semver?

        init(major: UInt8, minor: UInt8, patch: UInt8, preRelease: String?, oldestCompatibleVersion: Semver?) {
            self.major = major
            self.minor = minor
            self.patch = patch
            self.preRelease = preRelease
            self.oldestCompatibleVersion = oldestCompatibleVersion
        }

        /// Returns version in Semver format (e.g. v<major>.<minor>.<patch>-<preRelease>)
        /// as a String
        pub fun toString(): String {
            let semverCoreString = self.major.toString()
                 .concat(".")
                 .concat(
                     self.minor.toString()
                 ).concat(".")
                 .concat(
                     self.patch.toString()
                 )
            // Concat pre-release if it exists & return
            if self.preRelease != nil {
                return semverCoreString.concat("-").concat(self.preRelease!)
            }

            return semverCoreString
        }

        /* Custom Comparators */

        /// Returns true if Semver core is greater than
        /// passed Semver core and false otherwise
        pub fun coreGreaterThan(_ other: Semver): Bool {
            if (self.major > other.major) {
                return true
            } else if (self.major == other.major && self.minor > other.minor) {
                return true
            } else if (self.major == other.major && self.minor == other.minor && self.patch > other.patch) {
                return true
            } else {
                return false
            }
        }

        /// Returns true if Semver core is greater than or
        /// equal to passed Semver core and false otherwise
        pub fun coreGreaterThanOrEqualTo(_ other: Semver): Bool {
            return self.coreGreaterThan(other) || self.coreEqualTo(other)
        }

        /// Returns true if Semver core is less than
        /// passed Semver core and false otherwise
        pub fun coreLessThan(_ other: Semver): Bool {
            if self.major < other.major {
                return true
            } else if self.major == other.major && self.minor < other.minor {
                return true
            } else if self.major == other.major && self.minor == other.minor && self.patch < other.patch {
                return true
            } else {
                return false
            }
        }

        /// Returns true if Semver core is less than or
        /// equal to passed Semver core and false otherwise
        pub fun coreLessThanOrEqualTo(_ other: Semver): Bool {
            return self.coreLessThan(other) || self.coreEqualTo(other)
        }

        /// Returns true if Semver is equal to passed
        /// Semver core and false otherwise
        pub fun coreEqualTo(_ other: Semver): Bool {
            return self.major == other.major && self.minor == other.minor && self.patch == other.patch
        }

        /// Returns true if Semver is *exactly* equal to passed
        /// Semver and false otherwise
        pub fun strictEqualTo(_ other: Semver): Bool {
            return self.coreEqualTo(other) && self.preRelease == other.preRelease
        }

    }

    /// Event emitted any time a change is made to versionTable
    pub event ExecutionNodeVersionTableAddition(height: UInt64, version: Semver)
    pub event ExecutionNodeVersionTableDeletion(height: UInt64, version: Semver)
    /// Event emitted any time the version update buffer period is updated
    pub event ExecutionNodeVersionUpdateBufferUpdated(newVersionUpdateBuffer: UInt64)

    /// Canonical storage path for ExecutionNodeVersionKeeper
    pub let ExecutionNodeVersionKeeperStoragePath: StoragePath

    /// Table dictating minimum version - {blockHeight: Semver}
    /// Should be ordered by block height (index) which is
    /// enforced by insertion/deletion
    access(contract) let versionTable: {UInt64: Semver}

    /// Number of blocks between height at updating and target height for version rollover
    access(contract) var versionUpdateBuffer: UInt64
    /// Set expectations regarding how much the versionUpdateBuffer can vary between version boundaries
    access(contract) let versionUpdateBufferVariance: UFix64

    /// Cache of the last block boundary in the versionTable mapping
    /// Updated any time a change to the version table is made
    access(contract) var lastBlockBoundary: UInt64

    /// Admin interface that manages the Execution Node versioning
    /// maintained in this contract
    pub resource interface ExecutionNodeVersionAdmin {

        /// Update the minimum version to take effect at the given block height
        pub fun addMinimumVersion(targetBlockHeight: UInt64, newVersion: Semver) {
            pre {
                targetBlockHeight > ExecutionNodeVersionBeacon.lastBlockBoundary
                    : "Attempting to insert mapping out of order. Block Boundary insertions must be inserted in ascending order. Check versionTable & try again."
                targetBlockHeight > getCurrentBlock().height + ExecutionNodeVersionBeacon.versionUpdateBuffer
                    : "Target block height occurs too soon to update EN version."
            }
        }

        /// Deletes the last entry in versionTable which defines an upcoming version boundary
        /// Could be helpful in case rollback is needed
        pub fun deleteLastVersionMapping(): Semver {
            pre {
                ExecutionNodeVersionBeacon.versionTable.length > 0: "No version boundary mappings exist."
            }
        }

        /// Updates the number of blocks that must buffer updates to the versionTable
        /// and the block number the version is targetting
        pub fun updateVersionUpdateBuffer(newUpdateBufferInBlocks: UInt64) {
            post {
                ExecutionNodeVersionBeacon.versionUpdateBuffer == newUpdateBufferInBlocks: "Update buffer was not properly changed! Reverted."
            }
        }

        /// Assigns cached ExecutionNodeVersionBeacon.lastBlockBoundary to the last key in
        /// the versionTable if mappings are defined or 0 if the table is empty
        pub fun assignLastBlockBoundary()
    }

    /// Admin resource that manages the Execution Node versioning
    /// maintained in this contract
    pub resource ExecutionNodeVersionKeeper: ExecutionNodeVersionAdmin {
        pub fun addMinimumVersion(targetBlockHeight: UInt64, newVersion: Semver) {
            // Insert mapping into versiontable
            ExecutionNodeVersionBeacon.versionTable.insert(
                key: targetBlockHeight,
                newVersion
            )
            // Set lastBlockBoundary to passed target as we know it will be inserted in
            // ascending order due to pre-condition
            ExecutionNodeVersionBeacon.lastBlockBoundary = targetBlockHeight

            emit ExecutionNodeVersionTableAddition(height: targetBlockHeight, version: newVersion)
        }

        pub fun deleteLastVersionMapping(): Semver {
            // Ensure deletion occurs with enough time for nodes to respond
            assert(
                ExecutionNodeVersionBeacon.lastBlockBoundary > getCurrentBlock().height + ExecutionNodeVersionBeacon.versionUpdateBuffer,
                message: "Cannot delete version boundary within update buffer period or historical mappings."
            )

            // Remove the version mapping & emit
            let removed: Semver = ExecutionNodeVersionBeacon.versionTable.remove(
                key: ExecutionNodeVersionBeacon.lastBlockBoundary
            )!

            emit ExecutionNodeVersionTableDeletion(height: ExecutionNodeVersionBeacon.lastBlockBoundary, version: removed)

            // Reassign lastBlockBoundary
            self.assignLastBlockBoundary()

            // Return the removed version for verification
            return removed
        }

        pub fun updateVersionUpdateBuffer(newUpdateBufferInBlocks: UInt64) {
            // New buffer should be within range of expected buffer varianca
            assert(
                newUpdateBufferInBlocks >= UInt64(UFix64(ExecutionNodeVersionBeacon.versionUpdateBuffer) * (1.0 - ExecutionNodeVersionBeacon.versionUpdateBufferVariance)) &&
                newUpdateBufferInBlocks <= UInt64(UFix64(ExecutionNodeVersionBeacon.versionUpdateBuffer) * (1.0 + ExecutionNodeVersionBeacon.versionUpdateBufferVariance)),
                message: "Can only change versionUpdateBuffer by allowed variance from existing buffer."
            )

            let currentBlockHeight = getCurrentBlock().height
            // No boundaries defined beyond current block, safe to make changes
            if currentBlockHeight > ExecutionNodeVersionBeacon.lastBlockBoundary {
                ExecutionNodeVersionBeacon.versionUpdateBuffer = newUpdateBufferInBlocks
            } else {

                if let nextBlockBoundary = ExecutionNodeVersionBeacon.findNextVersionBoundary(blockHeight: currentBlockHeight) {
                    // If a version boundary exists in the mapping, ensure that the we're not currently within the buffer period of that boundary
                    // and that we are not within the new buffer period of that boundary
                    assert(
                        currentBlockHeight + ExecutionNodeVersionBeacon.versionUpdateBuffer < nextBlockBoundary &&
                        currentBlockHeight + newUpdateBufferInBlocks < nextBlockBoundary,
                        message: "Updating buffer now breaks version boundary update expectations. Try updating buffer after next version boundary."
                    )
                    // We can now safely change the versionUpdateBuffer
                    ExecutionNodeVersionBeacon.versionUpdateBuffer = newUpdateBufferInBlocks
                }
            }

            emit ExecutionNodeVersionUpdateBufferUpdated(newVersionUpdateBuffer: newUpdateBufferInBlocks)
        }

        pub fun assignLastBlockBoundary() {
            if ExecutionNodeVersionBeacon.versionTable.keys.length > 0 {
                ExecutionNodeVersionBeacon.lastBlockBoundary = ExecutionNodeVersionBeacon
                    .versionTable
                        .keys[(
                            ExecutionNodeVersionBeacon
                                .versionTable
                                    .keys
                                        .length - 1
                        )]
            } else {
                ExecutionNodeVersionBeacon.lastBlockBoundary = 0
            }
        }
    }

    /// Returns the current updateBuffer period within which Execution Nodes
    /// can be assured the version will not change
    pub fun getVersionUpdateBuffer(): UInt64 {
        return self.versionUpdateBuffer
    }

    /// Returns a copy of the full historical versionTable
    pub fun getVersionTable(): {UInt64: Semver} {
        return self.versionTable
    }

    /// Function that returns that minimum current version based on the current
    /// block height and version table mapping
    pub fun getCurrentMinimumExecutionNodeVersion(): Semver {
        pre {
            self.versionTable.length > 0: "No current minimum version defined."
        }
        // Check the previous boundary at the current block
        let currentBlockHeight = getCurrentBlock().height
        let previousBoundary = ExecutionNodeVersionBeacon.findPreviousBoundary(blockHeight: currentBlockHeight)!
        // Return the version defined at that boundary
        return self.versionTable[previousBoundary]!
    }

    /// Checks whether given version was compatible at the given block height
    pub fun isCompatibleVersion(blockHeight: UInt64, version: Semver): Bool {
        // Find previous version boundary & check minimum version in versionTable
        // at that boundary
        if let versionBoundary = ExecutionNodeVersionBeacon.findPreviousBoundary(blockHeight: blockHeight) {
            let minimumVersion = self.versionTable[versionBoundary]!

            // Returns Bool representing compatibility between versions
            if minimumVersion.oldestCompatibleVersion != nil && version.oldestCompatibleVersion != nil {
                return minimumVersion.coreGreaterThanOrEqualTo(version.oldestCompatibleVersion!) &&
                    version.coreGreaterThanOrEqualTo(minimumVersion.oldestCompatibleVersion!)
            } else {
                return version.coreGreaterThanOrEqualTo(minimumVersion)
            }
        } else {
            // Assuming no previous boundary exists, return false
            return false
        }
    }

    /// Returns an array containing the block number at which to update and
    /// associated version boundary - [blockBoundary: UInt64, version: Semver]
    /// If there is no upcoming version boundary defined, returns empty array - []
    pub fun getNextVersionBoundaryPair(): [AnyStruct?] {
        // Get the current block height
        let currentBlockHeight = getCurrentBlock().height

        // Return empty array if no version boundary mappings defined or
        // if current block exceeds the last block boundary defined
        if  self.versionTable.length == 0 || currentBlockHeight > self.lastBlockBoundary {
            return []
        }

        // We now know mappings are defined and that we are before the last defined
        // version boundary. We go on to find the next version boundary
        if let nextBoundary = ExecutionNodeVersionBeacon.findNextVersionBoundary(blockHeight: currentBlockHeight) {
            let nextVersion = self.versionTable[nextBoundary]!
            return [nextBoundary, nextVersion]
        }

        return []
    }

    /// Returns the block height defined in the previous version boundary found in versionTable
    /// If none exists, nil is returned
    access(contract) fun findPreviousBoundary(blockHeight: UInt64): UInt64? {
        // Search for previous version boundary
        return self.binarySearch(target: blockHeight)
    }

    /// Returns the block height defined in the upcoming version boundary found in versionTable
    /// If none exists, nil is returned
    access(contract) fun findNextVersionBoundary(blockHeight: UInt64): UInt64? {
        // No boundary following given blockHeight if it is greater or equal to
        // the last one defined. Return nil
        if blockHeight >= self.lastBlockBoundary {
            return nil
        }

        // Otherwise, look for the next boundary
        if let prevBoundary = self.binarySearch(target: blockHeight) {
            return self.versionTable.keys[
                (self.versionTable.keys.firstIndex(of: prevBoundary)! + 1)
            ]
        } else {
            return nil
        }
    }

    /// Binary search algorithm to find closest value key in versionTable that is <= target value
    access(contract) fun binarySearch(target: UInt64): UInt64? {
        // Return nil if the versionTable is empty
        if self.versionTable.length == 0 {
            return nil
        }

        // Define search space
        let boundaries = self.versionTable.keys
        // Return last block boundary if target is beyond
        if target >= self.lastBlockBoundary {
            return self.lastBlockBoundary
        }

        // Define search bounds
        let length = boundaries.length
        var left = 0
        var right = length

        // Loop until search pointers cross
        while left < right {
            var mid = (left + right) / 2
            if boundaries[mid] == target {
                return boundaries[mid]
            }
            if target < boundaries[mid] {
                if mid > 0 && target > boundaries[mid -1] {
                    return boundaries[mid - 1]
                }
                right = mid
            } else {
                if mid < (length - 1) && target < boundaries[mid + 1] {
                    return boundaries[mid]
                }
                left = mid + 1
            }
        }
        // Return nil if nothing found
        return nil
    }

    init() {
        /// Initialize variables
        self.ExecutionNodeVersionKeeperStoragePath = /storage/ExecutionNodeVersionKeeper
        self.versionTable = {}
        self.versionUpdateBuffer = 1000
        self.versionUpdateBufferVariance = 0.5
        self.lastBlockBoundary = 0

        /// Save
        self.account.save(<-create ExecutionNodeVersionKeeper(), to: self.ExecutionNodeVersionKeeperStoragePath)
    }
}
 