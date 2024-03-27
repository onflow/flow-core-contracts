import FlowServiceAccount from "FlowServiceAccount"

access(all) fun main(): {UInt64: UInt64} {
    return FlowServiceAccount.getExecutionMemoryWeights()
}