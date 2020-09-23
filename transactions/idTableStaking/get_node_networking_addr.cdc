import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the networking Address of a node

pub fun main(nodeID: String): String {
    return FlowIDTableStaking.getNodeNetworkingAddress(nodeID)!
}