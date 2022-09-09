import ExecutionNodeVersionBeacon from 0xEXECUTIONNODEVERSIONBEACONADDRESS

pub fun main(): {UInt64: ExecutionNodeVersionBeacon.Semver} {
    return ExecutionNodeVersionBeacon.getVersionTable()
}