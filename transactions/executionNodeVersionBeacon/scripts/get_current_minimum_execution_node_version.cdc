import ExecutionNodeVersionBeacon from 0x02

/// Gets the current minimum version defined in the versionTable
pub fun main(): ExecutionNodeVersionBeacon.Semver {
    return ExecutionNodeVersionBeacon.getCurrentMinimumExecutionNodeVersion()
}
