import "FlowFees"

access(all) fun main(): FlowFees.FeeParameters {
    return FlowFees.getFeeParameters()
}