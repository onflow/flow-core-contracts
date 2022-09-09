import ExecutionNodeVersionBeacon from 0xEXECUTIONNODEVERSIONBEACONADDRESS

pub fun main(myBlockHeight: UInt64, myVersion: ExecutionNodeVersionBeacon.Semver): Bool {
    return ExecutionNodeVersionBeacon.isCompatibleVersion(blockHeight: myBlockHeight, version: myVersion)
}