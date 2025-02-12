import "FlowIDTableStaking"

// This script gets all the info about a delegator and returns it

access(all) fun main(address: Address): FlowIDTableStaking.DelegatorInfo {

    let delegator = getAccount(address)
        .capabilities.borrow<&{FlowIDTableStaking.NodeDelegatorPublic}>(/public/flowStakingDelegator)
        ?? panic("Could not borrow reference to delegator object")

    return FlowIDTableStaking.DelegatorInfo(nodeID: delegator.nodeID, delegatorID: delegator.id)
}
