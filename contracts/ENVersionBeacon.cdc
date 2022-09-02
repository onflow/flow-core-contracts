/// This contract is used to defined block height and software version boundaries
/// for the software run by Execution Nodes.
pub contract ENVersionBeacon {

    /// Struct representing Execution Node software version
    /// along with helper functions
    pub struct ENVersion {
        pub let major: UInt8
        pub let minor: UInt8
        pub let patch: UInt8

        /// Returns true if this version is the current minimum version
        pub fun isSatisfactoryENVersion(version: ENVersion): Bool {
            return self.equalTo(ENVersionBeacon.getCurrentMinimumENVersion())
        }

        /// Returns true if ENVersion is greater than
        /// passed ENVersion and false otherwise
        pub fun greaterThan(_ other: ENVersion): Bool {
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

        /// Returns true if ENVersion is greater than or
        /// equal to passed ENVersion and false otherwise
        pub fun greaterThanOrEqualTo(_ other: ENVersion): Bool {
            return self.greaterThan(other) || self.equalTo(other)
        }

        /// Returns true if ENVersion is less than
        /// passed ENVersion and false otherwise
        pub fun lessThan(_ other: ENVersion): Bool {
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

        /// Returns true if ENVersion is less than or
        /// equal to passed ENVersion and false otherwise
        pub fun lessThanOrEqualTo(_ other: ENVersion): Bool {
            return self.lessThan(other) || self.equalTo(other)
        }

        /// Returns true if ENVersion is equal to passed
        /// ENVersion and false otherwise
        pub fun equalTo(_ other: ENVersion): Bool {
            return self.major == other.major && self.minor == other.minor && self.patch == other.patch
        }

        /// Returns version in Semver format (e.g. v<major>.<minor>.<patch>)
        /// as a String
        pub fun toString(): String {
            return "v".concat(
                self.major.toString()
                .concat(".")
                .concat(
                    self.minor.toString()
                    .concat(".")
                    .concat(
                        self.patch.toString()
                    )
                )
            )
        }

        init(major: UInt8, minor: UInt8, patch: UInt8) {
            self.major = major
            self.minor = minor
            self.patch = patch
        }
    }

    /// Event emitted any time a new version is added to the version table
    pub event ENVersionTableUpdated(height: UInt64, version: ENVersion)
    pub event ENVersionCooldownPeriodUpdated(newVersionCooldownPeriod: UInt64)

    /// Canonical storage path for ENVersionKeeper
    pub let ENVersionKeeperStoragePath: StoragePath

    /// Table dictating minimum version
    pub let versionTable: {UFix64: [ENVersion]}

    /*
    * TODO:
    *   - Establish admin resource that can update version table
    *   - Code conditions around updating that table (within 1000 blocks from current height & version increments)
    */
    /// Admin interface that manages the Execution Node versioning
    /// maintained in this contract
    pub interface ENVersionAdmin {
        access(self) versionCooldownPeriod: UInt64
        pub fun updateMinimumVersion() {
            // pre-conditions around blockheight threshold
        }

        pub fun getVersionCooldownPeriod(): UInt64 {
        }
    }

    /// Admin resource that manages the Execution Node versioning
    /// maintained in this contract
    pub resource ENVersionKeeper: ENVersionAdmin {
        access(self) versionCooldownPeriod: UInt64
        pub fun updateMinimumVersion() {
        }
        pub fun getVersionCooldownPeriod(): UInt64 {
            return self.versionCooldownPeriod
        }
        access(self) fun setVersionCooldownPeriod() {
        }

    }

    /// Function that returns that minimum current version based on the current
    /// block height and version table mapping
    pub fun getCurrentMinimumENVersion(): ENVersion {
        // TODO:
        //   - Find block height in versionTable that is closest to but less than current block height
        //   - Check the version listed as the value at that block height
        let currentHeight = getCurrentBlock().height
    }

    /// Checks whether given version was current at the given block height
    pub fun isMinimumENVersion(blockHeight: UInt64, version: ENVersion): Bool {
        // TODO:
        //   - Find block range where given blockHeight fits
        //   - See if given version is greater than version at that time
    }

    init() {
        self.versionTable = {}
        self.ENVersionKeeperStoragePath = /storage/ENVersionKeeper

        self.account.save(<-create ENVersionAdmin(), to: self.ENVersionKeeperStoragePath)
    }
}
