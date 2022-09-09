import ExecutionNodeVersionBeacon from 0x02

pub fun main(): ExecutionNodeVersionBeacon.Semver {
    return ExecutionNodeVersionBeacon.getCurrentMinimumExecutionNodeVersion()
}