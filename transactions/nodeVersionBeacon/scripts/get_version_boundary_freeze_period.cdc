import NodeVersionBeacon from "NodeVersionBeacon"

/// Returns the versionBoundaryFreezePeriod which defines the minimum number of blocks
/// that must pass between updating a version and its defined block height
/// boundary
access(all) fun main(): UInt64 {
    return NodeVersionBeacon.getVersionBoundaryFreezePeriod()
}