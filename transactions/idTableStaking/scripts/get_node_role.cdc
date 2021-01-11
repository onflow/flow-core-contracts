import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the role of a node

pub fun main(nodeID: String): UInt8 {
    let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeID)
    return nodeInfo.role
}