import ExecutionNodeVersionBeacon from 0xEXECUTIONNODEVERSIONBEACONADDRESS

/// Returns the variance factor by which the versionUpdateBuffer may change
/// Expect value to be between 0 and 1
pub fun main(): UFix64 {
    return ExecutionNodeVersionBeacon.getVersionUpdateBufferVariance()
}
