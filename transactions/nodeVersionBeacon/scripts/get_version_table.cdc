import NodeVersionBeacon from "./../../../contracts/NodeVersionBeacon.cdc"

/// Retrieves the versionTable defined in NodeVersionBeacon which
/// contains both historical and future version block height boundaries
pub fun main(): {UInt64: NodeVersionBeacon.Semver} {
    return NodeVersionBeacon.getVersionTable()
}