import FlowEpoch from "FlowEpoch"

access(all) fun main(): UInt64 {
    return FlowEpoch.proposedEpochCounter()
}