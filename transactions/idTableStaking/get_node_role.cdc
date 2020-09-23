import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the role of a node

pub fun main(nodeID: String): UInt8 {
    return FlowIDTableStaking.getNodeRole(nodeID)!
}