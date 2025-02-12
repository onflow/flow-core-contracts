import "FlowIDTableStaking"

// This script returns the current identity table length

access(all) fun main(): [String] {
    return FlowIDTableStaking.getNodeIDs()
}