import NodeVersionBeacon from 0xNODEVERSIONBEACONADDRESS

/// Returns a Bool signifying if the given version is valid at the given block height
/// or nil if the given block height is beyond the current block height
pub fun main(myBlockHeight: UInt64, myVersion: NodeVersionBeacon.Semver): Bool {
    return NodeVersionBeacon.isCompatibleVersion(blockHeight: myBlockHeight, version: myVersion)
}