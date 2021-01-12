import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the initial weight of a node

pub fun main(nodeID: String): UInt64 {
    let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeID)
    return nodeInfo.initialWeight
}