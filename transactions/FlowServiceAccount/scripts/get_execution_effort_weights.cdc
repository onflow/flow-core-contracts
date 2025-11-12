import "FlowServiceAccount"

access(all) fun main(): {UInt64: UInt64} {
    return FlowServiceAccount.getExecutionEffortWeights()
}