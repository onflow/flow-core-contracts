import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the networking key of a node

pub fun main(nodeID: String): String {
    return FlowIDTableStaking.getNodeNetworkingKey(nodeID)!
}