import "FlowIDTableStaking"

// This script returns the requested unstaking amount for a node

access(all) fun main(nodeID: String): UFix64 {
    let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeID)
    return nodeInfo.tokensRequestedToUnstake
}