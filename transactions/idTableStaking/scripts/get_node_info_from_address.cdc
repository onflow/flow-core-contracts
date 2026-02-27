import "FlowIDTableStaking"

// This script gets all the info about a node and returns it

access(all) fun main(address: Address): FlowIDTableStaking.NodeInfo {

    let authAccount = getAuthAccount<auth(Storage) &Account>(address)
    let nodeStakerRef = authAccount.storage.borrow<&FlowIDTableStaking.NodeStaker>(from: FlowIDTableStaking.NodeStakerStoragePath)
        ?? panic("Could not borrow reference to node staker object")

    return FlowIDTableStaking.NodeInfo(nodeID: nodeStakerRef.id)
}
