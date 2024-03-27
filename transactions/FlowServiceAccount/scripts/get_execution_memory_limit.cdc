import FlowServiceAccount from "FlowServiceAccount"

access(all) fun main(): UInt64 {
    return FlowServiceAccount.getExecutionMemoryLimit()
}