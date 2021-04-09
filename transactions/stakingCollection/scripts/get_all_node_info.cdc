import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS
import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

pub fun main(address: Address): [FlowIDTableStaking.NodeInfo] {
    return FlowStakingCollection.getAllNodeInfo(address: address)
}