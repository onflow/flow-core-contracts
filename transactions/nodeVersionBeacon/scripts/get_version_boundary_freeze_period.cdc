import NodeVersionBeacon from 0xNODEVERSIONBEACONADDRESS

/// Returns the versionBoundaryFreezePeriod which defines the minimum number of blocks
/// that must pass between updating a version and its defined block height
/// boundary
pub fun main(): UInt64 {
    return NodeVersionBeacon.getVersionBoundaryFreezePeriod()
}