import "FlowIDTableStaking"

// This script gets all the info about a node and returns it

access(all) fun main(nodeID: String): FlowIDTableStaking.NodeInfo {
    return FlowIDTableStaking.NodeInfo(nodeID: nodeID)
}
