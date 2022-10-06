import ExecutionNodeVersionBeacon from 0xEXECUTIONNODEVERSIONBEACONADDRESS

/// Retrieves the versionTable defined in ExecutionNodeVersionBeacon which
/// contains both historical and future version block height boundaries
pub fun main(): {UInt64: ExecutionNodeVersionBeacon.Semver} {
    return ExecutionNodeVersionBeacon.getVersionTable()
}