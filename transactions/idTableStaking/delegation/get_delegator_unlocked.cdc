import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns the balance of unlocked tokens of a delegator

pub fun main(nodeID: String, delegatorID: UInt32): UFix64 {
    return FlowIDTableStaking.getDelegatorUnlockedBalance(nodeID: nodeID, delegatorID: delegatorID)!
}