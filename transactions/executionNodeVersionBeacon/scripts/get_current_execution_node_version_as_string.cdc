import ExecutionNodeVersionBeacon from 0xEXECUTIONNODEVERSIONBEACONADDRESS

/// Gets the current version defined in the versionTable
/// as a String or nil if none is defined
pub fun main(): String? {
    if let version = ExecutionNodeVersionBeacon.getCurrentExecutionNodeVersion() {
        return version.toString()
    } else {
        return nil
    }
}
