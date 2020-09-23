import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the staking Key of a node

pub fun main(nodeID: String): String {
    return FlowIDTableStaking.getNodeStakingKey(nodeID)!
}