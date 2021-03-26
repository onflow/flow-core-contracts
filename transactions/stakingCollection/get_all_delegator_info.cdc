import StakingCollection from 0xSTAKINGCOLLECTION
import FlowIDTableStaking from 0xFLOWIDTABLESTAKINGADDRESS

pub fun main(address: Address): {String: {UInt32: FlowIDTableStaking.DelegatorInfo}} {
    return StakingCollection.getAllDelegatorInfo(address: address)
}