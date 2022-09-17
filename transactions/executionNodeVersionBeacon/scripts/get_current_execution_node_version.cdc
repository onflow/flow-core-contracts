import ExecutionNodeVersionBeacon from 0xEXECUTIONNODEVERSIONBEACONADDRESS

/// Gets the current version defined in the contract's versionTable
/// or nil if none is defined
pub fun main(): ExecutionNodeVersionBeacon.Semver? {
    return ExecutionNodeVersionBeacon.getCurrentExecutionNodeVersion()
}
