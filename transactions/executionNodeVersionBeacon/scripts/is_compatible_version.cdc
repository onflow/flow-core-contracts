import ExecutionNodeVersionBeacon from 0xEXECUTIONNODEVERSIONBEACONADDRESS

/// Returns a Bool signifying if the given version is valid at the given block height
/// or nil if the given block height is beyond the current block height
pub fun main(myBlockHeight: UInt64, myVersion: ExecutionNodeVersionBeacon.Semver): Bool {
    return ExecutionNodeVersionBeacon.isCompatibleVersion(blockHeight: myBlockHeight, version: myVersion)
}