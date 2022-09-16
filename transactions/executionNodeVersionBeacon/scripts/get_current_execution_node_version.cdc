import ExecutionNodeVersionBeacon from 0x02

/// Gets the current version defined in the contract's versionTable
pub fun main(): ExecutionNodeVersionBeacon.Semver? {
    return ExecutionNodeVersionBeacon.getCurrentExecutionNodeVersion()
}
