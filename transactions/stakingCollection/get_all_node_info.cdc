import StakingCollection from 0xSTAKINGCOLLECTION
import FlowIDTableStaking from 0xFLOWIDTABLESTAKINGADDRESS

pub fun main(address: Address): {String: FlowIDTableStaking.NodeInfo} {
    return StakingCollection.getAllNodeInfo(address: address)
}