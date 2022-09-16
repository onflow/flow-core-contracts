import ExecutionNodeVersionBeacon from 0x02

/// Gets the current version defined in the versionTable
/// as a String
pub fun main(): String {
    if let version = ExecutionNodeVersionBeacon.getCurrentExecutionNodeVersion() {
        return version.toString()
    } else {
        return null
    }
}
