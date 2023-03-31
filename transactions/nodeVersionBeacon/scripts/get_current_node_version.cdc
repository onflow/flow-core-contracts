import NodeVersionBeacon from 0xNODEVERSIONBEACONADDRESS

/// Gets the current version defined in the contract's versionTable
pub fun main(): NodeVersionBeacon.Semver {
    return NodeVersionBeacon.getCurrentVersionBoundary().version
}
