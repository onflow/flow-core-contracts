import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This script returns all the info associated with a delegator

pub fun main(nodeID: String, delegatorID: UInt32): FlowIDTableStaking.DelegatorInfo {
    return FlowIDTableStaking.DelegatorInfo(nodeID: nodeID, delegatorID: delegatorID)
}