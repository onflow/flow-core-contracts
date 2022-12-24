import NodeVersionBeacon from "./../../../contracts/NodeVersionBeacon.cdc"

/// Retrieves the next version boundary pair in array of length == 2
/// returnArray[0]: UInt64 - block height
/// returnArray[1]: NodeVersionBeacon.Semver
/// Returns empty array if there is no upcoming version boundary defined
pub fun main(): [AnyStruct] {
    return NodeVersionBeacon.getNextVersionBoundaryPair()
}
