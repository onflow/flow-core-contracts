/// This contract is used to defined block height and software version boundaries
/// for the software run by Execution Nodes.
pub contract interface IENVersionBeacon {

    pub enum ENVersionUpdateAction: UInt8 {
        pub case added
        pub case deleted
        pub case amended
    }

    /// Struct representing Execution Node software version
    /// along with helper functions
    pub struct ENVersion {
        /// Compnents defining a semantic version
        pub let major: UInt8
        pub let minor: UInt8
        pub let patch: UInt8

        /// Oldest compatitible version with this version
        ///
        /// Defining this can help with logic around updating before a target block is reached
        /// Such behavior may be desireable in the event breaking changes are released
        /// between versions
        pub let oldestCompatibleVersion: ENVersion

        init(major: UInt8, minor: UInt8, patch: UInt8, oldestCompatibleVersion: ENVersion)

        /// Returns version in Semver format (e.g. v<major>.<minor>.<patch>)
        /// as a String
        pub fun toString(): String

        /* Custom Comparators */

        /// Returns true if ENVersion is greater than
        /// passed ENVersion and false otherwise
        pub fun greaterThan(_ other: ENVersion): Bool

        /// Returns true if ENVersion is greater than or
        /// equal to passed ENVersion and false otherwise
        pub fun greaterThanOrEqualTo(_ other: ENVersion): Bool

        /// Returns true if ENVersion is less than
        /// passed ENVersion and false otherwise
        pub fun lessThan(_ other: ENVersion): Bool

        /// Returns true if ENVersion is less than or
        /// equal to passed ENVersion and false otherwise
        pub fun lessThanOrEqualTo(_ other: ENVersion): Bool

        /// Returns true if ENVersion is equal to passed
        /// ENVersion and false otherwise
        pub fun equalTo(_ other: ENVersion): Bool
    }

    /// Event emitted any time a new version is added to the version table
    pub event ENVersionTableUpdated(height: UInt64, version: ENVersion, action: ENVersionUpdateAction)

    /// Event emitted any time the version cooldown period is updated
    pub event ENVersionCooldownPeriodUpdated(newVersionCooldownPeriod: UInt64)

    /// Canonical storage path for ENVersionKeeper
    pub let ENVersionAdminStoragePath: StoragePath

    /// Table dictating minimum version - {blockHeight: ENVersion}
    access(contract) let versionTable: {UInt64: ENVersion}

    /// Number of blocks between height at updating and target height for version rollover
    access(contract) let versionCooldownPeriod: UInt64

    /// Admin interface that manages the Execution Node versioning
    /// maintained in this contract
    pub resource interface ENVersionAdmin {

        /// Update the minimum version to take effect at the given block height
        pub fun addMinimumVersion(targetblockHeight: UInt64, version: ENVersion) {
            pre {
                targetblockHeight > getCurrentBlock().height + ENVersionAdmin.versionCooldownPeriod: "Target block height occurs too soon to update EN version"
            }
            emit EMVersionTableUpdated(height: targetblockHeight, version: version, action: ENVersionAction.added)
        }

        /// Deletes the entry in versionTable at the passed block height
        /// Could be helpful in event of rollback
        pub fun deleteBlockTargetVersionMapping(blockHeight: UInt64, version: ENVersion) {
            pre {
                targetblockHeight > getCurrentBlock().height + ENVersionAdmin.versionCooldownPeriod: "Target block height occurs too soon to update EN version"
            }
            emit EMVersionTableUpdated(height: targetblockHeight, version: version, action: ENVersionAction.deleted)
        }

        pub fun updateVersionCooldownPeriod(cooldownInBlocks: UInt64) {
            emit ENVersionCooldownPeriodUpdated(newVersionCooldownPeriod: cooldownInBlocks)
        }
    }

    /// Returns the current cooldown period within which ENs
    /// can be assured version will not change
    pub fun getVersionCooldownPeriod(): UInt64

    /// Function that returns that minimum current version based on the current
    /// block height and version table mapping
    pub fun getCurrentMinimumENVersion(): ENVersion

    /// Returns a copy of the full historical versionTable
    pub fun getVersionTable(): {ENVersion: UInt64}

    /// Checks whether given version was compatible at the given block height
    pub fun isCompatibleENVersion(blockHeight: UInt64, version: ENVersion): Bool

    /// Returns
    pub fun getNextVersion

    init() {
        self.versionTable = {}
        self.ENVersionAdminStoragePath = /storage/ENVersionAdmin

        self.account.save(<-create ENVersionAdmin(), to: self.ENVersionAdminStoragePath)
    }
}
