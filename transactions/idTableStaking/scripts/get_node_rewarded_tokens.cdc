import FlowIDTableStaking from "FlowIDTableStaking"

// This script returns the balance of rewarded tokens of a node

access(all) fun main(nodeID: String): UFix64 {
    let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeID)
    return nodeInfo.tokensRewarded
}