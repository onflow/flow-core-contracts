import "FlowIDTableStaking"

// This script returns the networking Address of a node

access(all) fun main(nodeID: String): String {
    let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeID)
    return nodeInfo.networkingAddress
}