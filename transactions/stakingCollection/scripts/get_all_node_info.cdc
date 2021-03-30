import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS
import FlowIDTableStaking from 0xFLOWIDTABLESTAKINGADDRESS

pub fun main(address: Address): {String: FlowIDTableStaking.NodeInfo} {
    return StakingCollection.getAllNodeInfo(address: address)
}