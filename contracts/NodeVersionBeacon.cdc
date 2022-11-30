/// This contract is used to defined block height and software version boundaries
/// for all nodes.
pub contract NodeVersionBeacon {

    /// Struct representing software version as Semantic Version
    /// along with helper functions
    /// For reference, see https://semver.org/
    pub struct Semver {
        /// Components defining a semantic version
        pub let major: UInt8
        pub let minor: UInt8
        pub let patch: UInt8
        pub let preRelease: String?

        /// Value denoting compatibility with previous versions
        pub let isBackwardsCompatible: Bool

        init(major: UInt8, minor: UInt8, patch: UInt8, preRelease: String?, isBackwardsCompatible: Bool) {
            self.major = major
            self.minor = minor
            self.patch = patch
            self.preRelease = preRelease
            self.isBackwardsCompatible = isBackwardsCompatible
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
            return !self.coreGreaterThanOrEqualTo(other)
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
    pub event NodeVersionTableAddition(height: UInt64, version: Semver)
    pub event NodeVersionTableDeletion(height: UInt64, version: Semver)

    /// Event emitted any time the version update buffer period or variance is updated
    pub event NodeVersionUpdateBufferChanged(newVersionUpdateBuffer: UInt64)

    /// Canonical storage path for NodeVersionAdmin
    pub let NodeVersionAdminStoragePath: StoragePath

    /// Table dictating minimum version - {blockHeight: Semver}
    /// Should be ordered by block height (index) which is
    /// enforced by insertion/deletion
    access(contract) let versionTable: {UInt64: Semver}

    /// Number of blocks between block height when version boundary is defined and
    /// the version boundary being defined. Nodes can expect that changes to the versionTable
    /// they will have at least this long to respond to a version boundary
    access(contract) var versionUpdateBuffer: UInt64

    /// Sorted Array containing future block heights where a version boundary is defined
    /// We'll maintain this as easy mechanism for determining proximal version block boundaries
    access(contract) var upcomingBlockBoundaries: [UInt64]

    /// Sorted Array containing historical block heights where version boundaries were defined
    access(contract) var archivedBlockBoundaries: [UInt64]

    /// Admin resource that manages node versioning
    /// maintained in this contract
    pub resource NodeVersionAdmin {
        /// Update the minimum version to take effect at the given block height
        pub fun addVersionBoundaryToTable(targetBlockHeight: UInt64, newVersion: Semver) {
            pre {
                targetBlockHeight > getCurrentBlock().height + NodeVersionBeacon.versionUpdateBuffer
                    : "Target block height occurs too soon to update EN version."
            }

            // Insert mapping into version table
            NodeVersionBeacon.versionTable.insert(
                key: targetBlockHeight,
                newVersion
            )
            // Insert the version boundary's target block height into the
            // array maintaining all upcoming block height boundaries
            NodeVersionBeacon.insertUpcomingBlockBoundary(targetBlockHeight)

            emit NodeVersionTableAddition(height: targetBlockHeight, version: newVersion)
        }

        /// Deletes the last entry in versionTable which defines an upcoming version boundary
        /// Could be helpful in case rollback is needed
        pub fun deleteUpcomingVersionBoundary(blockHeight: UInt64): Semver {
            pre {
                NodeVersionBeacon.versionTable.keys.contains(blockHeight): "No boundary defined at that blockHeight."
                NodeVersionBeacon.upcomingBlockBoundaries.contains(blockHeight): "Boundary not defined in upcomingBlockBoundaries."
            }

            // Ensure deletion occurs with enough time for nodes to respond
            assert(
                blockHeight > getCurrentBlock().height + NodeVersionBeacon.versionUpdateBuffer,
                message: "Cannot delete version boundary within update buffer period or historical mappings."
            )

            // Remove the version mapping and upcomingBlockBoundaries then emit event
            let removed: Semver = NodeVersionBeacon.versionTable.remove(
                key: blockHeight
            )!
            NodeVersionBeacon.upcomingBlockBoundaries.remove(
                at: NodeVersionBeacon.upcomingBlockBoundaries.firstIndex(of: blockHeight)!
            )

            emit odeVersionTableDeletion(height: blockHeight, version: removed)

            // Clean up upcoming & archived block boundaries before
            // returning removed version for verification
            NodeVersionBeacon.archiveOldBlockBoundaries()
            return removed
        }

        /// Updates the number of blocks that must buffer updates to the versionTable
        /// and the block number the version is targeting
        pub fun changeVersionUpdateBuffer(newUpdateBufferInBlocks: UInt64) {
            post {
                NodeVersionBeacon.versionUpdateBuffer == newUpdateBufferInBlocks: "Update buffer was not properly changed! Reverted."
            }

            // Get current block height.
            let currentBlockHeight = getCurrentBlock().height
            // Cleanup the upcoming block numbers
            NodeVersionBeacon.archiveOldBlockBoundaries();

            // No boundaries defined beyond current block, safe to make changes
            if NodeVersionBeacon.upcomingBlockBoundaries.length == 0 {
                NodeVersionBeacon.versionUpdateBuffer = newUpdateBufferInBlocks
            } else {
                // Get the proximal upcoming boundary
                let nextBlockBoundary = NodeVersionBeacon.upcomingBlockBoundaries[0]

                // Ensure that the we're not currently within the old or new buffer period
                // of the next block height boundary
                assert(
                    currentBlockHeight + NodeVersionBeacon.versionUpdateBuffer < nextBlockBoundary &&
                    currentBlockHeight + newUpdateBufferInBlocks < nextBlockBoundary,
                    message: "Updating buffer now breaks version boundary update expectations. Try updating buffer after next version boundary."
                )

                // We can now safely change the versionUpdateBuffer
                NodeVersionBeacon.versionUpdateBuffer = newUpdateBufferInBlocks
            }

            emit NodeVersionUpdateBufferChanged(newVersionUpdateBuffer: newUpdateBufferInBlocks)
        }
    }

    /// Returns the current updateBuffer period within which nodes
    /// can be assured the version will not change
    pub fun getVersionUpdateBuffer(): UInt64 {
        return self.versionUpdateBuffer
    }

    /// Returns a copy of the full historical versionTable
    pub fun getVersionTable(): {UInt64: Semver} {
        return self.versionTable
    }

    /// Function that returns the version that was defined at the most
    /// recent block height boundary or null if no upcoming boundary is defined
    pub fun getCurrentNodeVersion(): Semver? {
        // Update both upcomingBlockBoundaries & archivedBlockBoundaries arrays
        self.archiveOldBlockBoundaries()

        // Return nil if no historical boundaries have been defined
        if self.versionTable.length == 0 || self.archivedBlockBoundaries.length == 0 {
            return nil
        }

        // Return the version mapped to the last historical block height boundary
        return self.versionTable[UInt64(self.archivedBlockBoundaries.length - 1)]
    }

    /// Returns an array containing the block number at which to update and
    /// associated version boundary - [blockBoundary: UInt64, version: Semver]
    /// If there is no upcoming version boundary defined, returns empty array - []
    pub fun getNextVersionBoundaryPair(): [AnyStruct] {

        // Update upcomingBlockBoundaries so we know we're only dealing with future boundaries
        self.archiveOldBlockBoundaries()

        // No Future boundaries defined OR table contains no versions will
        // return empty array as there are no boundaries to be concerned with
        if self.upcomingBlockBoundaries.length == 0 || self.versionTable.length == 0 {
            return []
        }

        // By now we know the next boundary we're concerned with is defined as
        // the first element in the upcomingBlockBoundaries array
        return [
            self.upcomingBlockBoundaries[0],
            self.versionTable[self.upcomingBlockBoundaries[0]]
        ]
    }

    /// Checks whether given version was compatible at the given historical block height
    pub fun isCompatibleVersion(blockHeight: UInt64, version: Semver): Bool {
        if blockHeight > getCurrentBlock().height {
            return false
        }

        // Find previous version boundary & check minimum version in versionTable
        // at that boundary
        if let versionBoundary = self.searchForClosestHistoricalBlockBoundary(blockHeight) {
            let minimumVersion = self.versionTable[versionBoundary]!

            // Either the version is greater than or equal to the minimum stated version
            // at that block boundary
            // OR
            // the minimum stated version is backwards compatible
            return (
                version.coreGreaterThanOrEqualTo(minimumVersion)
                && version.isBackwardsCompatible
                )
                || minimumVersion.isBackwardsCompatible
        }
        // Assuming no previous boundary exists, return false
        return false
    }

    /// Find the ascending sort insertion index for the passed block height
    access(contract) fun insertUpcomingBlockBoundary(_ targetBlockHeight: UInt64) {
        // Update upcoming & archived block boundaries based on current block height
        self.archiveOldBlockBoundaries()

        // If there are no upcomingBlockBoundaries or targetBlockHeight is beyond all
        // upcoming block boundaries, simply append
        if self.upcomingBlockBoundaries.length == 0
            || targetBlockHeight > self.upcomingBlockBoundaries[self.upcomingBlockBoundaries.length - 1] {
            self.upcomingBlockBoundaries.append(targetBlockHeight)
        }

        // Find the index of the closest block height less than the target
        var i = 0
        while self.upcomingBlockBoundaries[i] < targetBlockHeight {
            i = i + 1
        }
        // Insert at the discovered appropriate index
        self.upcomingBlockBoundaries.insert(at: i, targetBlockHeight)
    }

    /// Removes historic block heights from array maintaining upcoming block version boundaries
    pub fun archiveOldBlockBoundaries() {
        // Check block height when function is called
        let currentBlockHeight = getCurrentBlock().height

        // Clear previous block heights from upcomingBlockBoundaries in the array
        // and append to archivedBlockBoundaries
        while self.upcomingBlockBoundaries.length > 0 && self.upcomingBlockBoundaries[0] < currentBlockHeight {
            let archivedBlockBoundary = self.upcomingBlockBoundaries.removeFirst()
            self.archivedBlockBoundaries.append(archivedBlockBoundary)
        }
    }

    /// Binary search algorithm to find closest value key in versionTable that is <= target value
    access(contract) fun searchForClosestHistoricalBlockBoundary(_ target: UInt64): UInt64? {
        // Update archived and future block height boundaries
        self.archiveOldBlockBoundaries()

        // Return nil if the versionTable is empty or no historical
        // block height boundaries have been defined
        if self.versionTable.length == 0 || self.archivedBlockBoundaries.length == 0 {
            return nil
        }

        // Return last block boundary if target is beyond
        let archiveLength = self.archivedBlockBoundaries.length
        if target >= self.archivedBlockBoundaries[archiveLength - 1] {
            return self.archivedBlockBoundaries[archiveLength - 1]
        }

        // Define search bounds
        var left = 0
        var right = archiveLength
        // Loop until search pointers cross
        while left < right {
            var mid = (left + right) / 2
            if self.archivedBlockBoundaries[mid] == target {
                return self.archivedBlockBoundaries[mid]
            }
            if target < self.archivedBlockBoundaries[mid] {
                if mid > 0 && target > self.archivedBlockBoundaries[mid -1] {
                    return self.archivedBlockBoundaries[mid - 1]
                }
                right = mid
            } else {
                if mid < (archiveLength - 1) && target < self.archivedBlockBoundaries[mid + 1] {
                    return self.archivedBlockBoundaries[mid]
                }
                left = mid + 1
            }
        }
        // Return nil if nothing found
        return nil
    }

    init(versionUpdateBuffer: UInt64) {
        /// Initialize contract variables
        self.NodeVersionAdminStoragePath = /storage/NodeVersionAdmin
        self.versionTable = {}
        self.versionUpdateBuffer = versionUpdateBuffer
        self.archivedBlockBoundaries = []
        self.upcomingBlockBoundaries = []

        /// Save NodeVersionAdmin to storage
        self.account.save(<-create NodeVersionAdmin(), to: self.NodeVersionAdminStoragePath)
    }
}
 