import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the balance of unstaking tokens of a delegator

pub fun main(nodeID: String, delegatorID: UInt32): UFix64 {
    let delInfo = FlowIDTableStaking.DelegatorInfo(nodeID: nodeID, delegatorID: delegatorID)
    return delInfo.tokensRequestedToUnstake
}