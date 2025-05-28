import "FlowEpoch"

access(all) fun main(epochCounter: UInt64): FlowEpoch.EpochMetadata {
    return FlowEpoch.getEpochMetadata(epochCounter)!
}