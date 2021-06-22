import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script gets all the info about a delegator and returns it

pub fun main(address: Address): FlowIDTableStaking.DelegatorInfo {

    let delegator = getAccount(address)
        .getCapability<&{FlowIDTableStaking.NodeDelegatorPublic}>(/public/flowStakingDelegator)
        .borrow()
        ?? panic("Could not borrow reference to delegator object")

    return FlowIDTableStaking.DelegatorInfo(nodeID: delegator.nodeID, delegatorID: delegator.id)
}
