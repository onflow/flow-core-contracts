import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the initial weight of a node

pub fun main(nodeID: String): UInt64 {
    return FlowIDTableStaking.getNodeInitialWeight(nodeID)!
}