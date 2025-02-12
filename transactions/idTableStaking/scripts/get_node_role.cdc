import "FlowIDTableStaking"

// This script returns the role of a node

access(all) fun main(nodeID: String): UInt8 {
    let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeID)
    return nodeInfo.role
}