import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS
import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

/// Tells if the specified node or delegator exists in the staking collection 
/// for the specified address

pub fun main(address: Address, nodeID: String, delegatorID: UInt32?): Bool {
    return FlowStakingCollection.doesStakeExist(address: address, nodeID: nodeID, delegatorID: delegatorID)
}