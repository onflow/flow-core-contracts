/// This contract is used to defined block height and software version boundaries
/// for the software run by Execution Nodes.
pub contract ExecutionNodeVersionBeacon {

    pub enum ExecutionNodeVersionUpdateAction: UInt8 {
        pub case added
        pub case deleted
        pub case amended
    }

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
        pub let oldestCompatibleVersion: ENVersion

        init(major: UInt8, minor: UInt8, patch: UInt8, preRelease: String?, oldestCompatibleVersion: Semver) {
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
            if preRelease != nil {
                return semverCoreString.concat("-").concat(preRelease!)
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
            return self.greaterThan(other) || self.equalTo(other)
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
            return self.lessThan(other) || self.equalTo(other)
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

    /// Event emitted any time a new version is added to the version table
    pub event ExecutionNodeVersionTableUpdated(height: UInt64, version: Semver)
    pub event ExecutionNodeVersionUpdateBufferUpdated(newVersionUpdateBuffer: UInt64)

    /// Canonical storage path for ENVersionKeeper
    pub let ENVersionAdminStoragePath: StoragePath

    /// Table dictating minimum version - {blockHeight: ENVersion}
    access(contract) let versionTable: {UInt64: Semver}

    /// Number of blocks between height at updating and target height for version rollover
    access(contract) let versionUpdateBuffer: UInt64

    /*
    * TODO:
    *   - Consider changing event names & remove enums
    */

    /// Admin interface that manages the Execution Node versioning
    /// maintained in this contract
    pub resource interface ExecutionNodeVersionAdmin {

        /// Update the minimum version to take effect at the given block height
        pub fun addMinimumVersion(targetblockHeight: UInt64, version: ENVersion) {
            pre {
                targetblockHeight > getCurrentBlock().height + ExecutionNodeVersionBeacon.versionUpdateBuffer: "Target block height occurs too soon to update EN version"
            }
        }

        /// Deletes the entry in versionTable at the passed block height
        /// Could be helpful in event of rollback
        pub fun deleteBlockTargetVersionMapping(targetblockHeight: UInt64, version: ENVersion) {
            pre {
                targetblockHeight > getCurrentBlock().height + ExecutionNodeVersionBeacon.versionUpdateBuffer: "Target block height occurs too soon to update EN version"
            }
        }

        pub fun updateVersionUpdateBuffer(updateBufferInBlocks: UInt64) {
            post {
                self.versionUpdateBuffer == updateBufferInBlocks: "Update buffer was not properly changed! Reverted."
            }
        }
    }

    /// Admin resource that manages the Execution Node versioning
    /// maintained in this contract
    pub resource ExecutionNodeVersionKeeper: ExecutionNodeVersionAdmin {
        pub fun addMinimumVersion(targetblockHeight: UInt64, version: ENVersion) {
            // TODO - logic
            emit EMVersionTableUpdated(height: targetblockHeight, version: version, action: ENVersionAction.added)
        }

        pub fun deleteBlockTargetVersionMapping(blockHeight: UInt64, version: ENVersion) {
            // TODO - logic
            emit EMVersionTableUpdated(height: targetblockHeight, version: version, action: ENVersionAction.deleted)
        }

        pub fun updateVersionUpdateBuffer(updateBufferInBlocks: UInt64) {
            // TODO - logic
            emit ExecutionNodeUpdateBufferUpdated(newVersionUpdateBuffer: updateBufferInBlocks)
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
        // TODO:
        //   - Find block height in versionTable that is closest to but less than current block height
        //   - Check the version listed as the value at that block height
        let currentHeight = getCurrentBlock().height
    }

    /// Checks whether given version was compatible at the given block height
    pub fun isCompatibleENVersion(blockHeight: UInt64, version: Semver): Bool {
        // TODO:
        //   - Find block range where given blockHeight fits
        //   - See if given version is greater than version at that time
    }

    /// Returns an array containing the block number at which to update and
    /// associated version boundary
    pub fun getNextVersionBoundaryPair(): [UInt64, Semver] {
        if getCurrentBlock().height >
    }

    init() {
        self.versionTable = {}
        self.versionUpdateBuffer = 1000
        self.ENVersionKeeperStoragePath = /storage/ENVersionKeeper

        self.account.save(<-create ENVersionAdmin(), to: self.ENVersionKeeperStoragePath)
    }
}
 