import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS
import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

pub fun main(address: Address, nodeID: String, delegatorID: UInt32?): Bool {
    return FlowStakingCollection.doesStakeExist(address: address, nodeID: nodeID, delegatorID: delegatorID)
}