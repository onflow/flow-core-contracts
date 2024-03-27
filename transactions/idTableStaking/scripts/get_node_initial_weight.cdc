import FlowIDTableStaking from "FlowIDTableStaking"

// This script returns the initial weight of a node

access(all) fun main(nodeID: String): UInt64 {
    let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeID)
    return nodeInfo.initialWeight
}