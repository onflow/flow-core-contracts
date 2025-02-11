import "FlowEpoch"

access(all) fun main(): FlowEpoch.Config {
    return FlowEpoch.getConfigMetadata()
}
