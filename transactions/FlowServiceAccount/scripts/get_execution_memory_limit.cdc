import "FlowServiceAccount"

access(all) fun main(): UInt64 {
    return FlowServiceAccount.getExecutionMemoryLimit()
}