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

        pub fun greaterThanOrEqualTo(_ other: ENVersion): Bool {
            return self.greaterThan(other) || self.equalTo(other)
        }

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

        pub fun lessThanOrEqualTo(_ other: ENVersion): Bool {
            return self.lessThan(other) || self.equalTo(other)
        }

        pub fun equalTo(_ other: ENVersion): Bool {
            return self.major == other.major && self.minor == other.minor && self.patch == other.patch
        }

        // Returns version in Semver format (e.g. v<major>.<minor>.<patch>)
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

    /*
    * TODO:
    *   - Establish admin resource that can update version table
    *   - Code conditions around updating that table (within 1000 blocks from current height & version increments)
    */

    pub resource ENVersionKeeper {

    }

    /// Event emitted any time a new version is added to the version table
    pub event ENVersionTableUpdated(height: UInt64, version: ENVersion)

    /// Table dictating minimum version
    pub let versionTable: {UFix64: [ENVersion]}

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
    }
}
