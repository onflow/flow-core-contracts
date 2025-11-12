import "FlowServiceAccount"
import "FlowExecutionParameters"

access(all) fun main(): {UInt64: UInt64} {
    return FlowExecutionParameters.getExecutionEffortWeights()
}