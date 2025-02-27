import "FlowEpoch"

access(all) fun main(): UInt64 {
    return FlowEpoch.currentEpochCounter
}