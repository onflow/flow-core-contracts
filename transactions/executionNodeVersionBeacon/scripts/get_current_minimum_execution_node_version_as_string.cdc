import ExecutionNodeVersionBeacon from 0x02

/// Gets the current minimum version defined in the versionTable
/// as a String
pub fun main(): String {
    return ExecutionNodeVersionBeacon.getCurrentMinimumExecutionNodeVersion().toString()
}
