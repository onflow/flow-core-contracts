import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the staking Key of a node

pub fun main(nodeID: String): String {
    let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeID)
    return nodeInfo.stakingKey
}