import FlowEpoch from "FlowEpoch"

access(all) fun main(): FlowEpoch.EpochTimingConfig {
    return FlowEpoch.getEpochTimingConfig()
}