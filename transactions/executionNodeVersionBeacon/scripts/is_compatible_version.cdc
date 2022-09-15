import ExecutionNodeVersionBeacon from 0xEXECUTIONNODEVERSIONBEACONADDRESS

/// Returns a Bool signifying if the given version is valid at the given block height
pub fun main(myBlockHeight: UInt64, myVersion: ExecutionNodeVersionBeacon.Semver): Bool {
    return ExecutionNodeVersionBeacon.isCompatibleVersion(blockHeight: myBlockHeight, version: myVersion)
}