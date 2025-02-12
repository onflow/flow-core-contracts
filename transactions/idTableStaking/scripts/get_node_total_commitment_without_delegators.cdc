import "FlowIDTableStaking"

// This script returns the balance of staked tokens of a node

access(all) fun main(nodeID: String): UFix64 {
    let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeID)
    return nodeInfo.totalCommittedWithoutDelegators()
}
