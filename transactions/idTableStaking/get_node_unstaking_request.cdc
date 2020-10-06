import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the requested unstaking amount for a node

pub fun main(nodeID: String): UFix64 {
    let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeID)
    return nodeInfo.tokensRequestedToUnstake
}