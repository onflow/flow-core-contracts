import NodeVersionBeacon from 0xNODEVERSIONBEACONADDRESS

/// Gets the current version defined in the contract's versionTable
/// or nil if none is defined
pub fun main(): NodeVersionBeacon.Semver? {
    return NodeVersionBeacon.getCurrentNodeVersion()
}