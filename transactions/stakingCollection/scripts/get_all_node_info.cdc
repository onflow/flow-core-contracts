import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS
import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

/// Gets an array of all the node metadata for nodes stored in the staking collection

pub fun main(address: Address): [FlowIDTableStaking.NodeInfo] {
    return FlowStakingCollection.getAllNodeInfo(address: address)
}