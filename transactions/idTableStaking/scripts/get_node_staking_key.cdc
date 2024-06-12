import FlowIDTableStaking from "FlowIDTableStaking"

// This script returns the staking Key of a node

access(all) fun main(nodeID: String): String {
    let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeID)
    return nodeInfo.stakingKey
}