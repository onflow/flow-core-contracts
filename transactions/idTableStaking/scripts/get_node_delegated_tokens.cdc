import FlowIDTableStaking from 0x8624b52f9ddcd04a

// This script returns the balance of staked tokens of a node

pub fun main(nodeID: String): UFix64 {
    let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeID)
    return nodeInfo.totalStakedWithDelegators() - nodeInfo.tokensStaked
}