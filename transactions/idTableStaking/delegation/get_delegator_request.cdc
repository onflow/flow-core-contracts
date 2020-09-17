import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the requested unstaking balance of a delegator

pub fun main(nodeID: String, delegatorID: UInt32): UFix64 {
    return FlowIDTableStaking.getDelegatorUnstakingRequest(nodeID: nodeID, delegatorID: delegatorID)!
}