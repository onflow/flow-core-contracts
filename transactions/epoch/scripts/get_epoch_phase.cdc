import "FlowEpoch"

access(all) fun main(): UInt8 {
    return FlowEpoch.currentEpochPhase.rawValue
}