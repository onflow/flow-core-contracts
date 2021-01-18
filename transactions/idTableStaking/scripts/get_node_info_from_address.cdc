import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script gets all the info about a node and returns it

pub fun main(address: Address): FlowIDTableStaking.NodeInfo {

    let nodeStaker = getAccount(address)
        .getCapability<&{FlowIDTableStaking.NodeStakerPublic}>(FlowIDTableStaking.NodeStakerPublicPath)
        .borrow()
        ?? panic("Could not borrow reference to node staker object")

    return FlowIDTableStaking.NodeInfo(nodeID: nodeStaker.id)
}
