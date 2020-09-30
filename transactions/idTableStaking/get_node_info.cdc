import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script gets all the info about a node and returns it

pub fun main(nodeID: String): FlowIDTableStaking.NodeInfo {
    return FlowIDTableStaking.NodeInfo(nodeID: nodeID)
}