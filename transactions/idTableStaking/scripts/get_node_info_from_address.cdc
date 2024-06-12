import FlowIDTableStaking from "FlowIDTableStaking"

// This script gets all the info about a node and returns it

access(all) fun main(address: Address): FlowIDTableStaking.NodeInfo {

    let nodeStaker = getAccount(address)
        .capabilities.borrow<&{FlowIDTableStaking.NodeStakerPublic}>(FlowIDTableStaking.NodeStakerPublicPath)
        ?? panic("Could not borrow reference to node staker object")

    return FlowIDTableStaking.NodeInfo(nodeID: nodeStaker.id)
}
