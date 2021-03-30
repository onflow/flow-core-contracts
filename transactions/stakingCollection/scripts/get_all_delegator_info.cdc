import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS
import FlowIDTableStaking from 0xFLOWIDTABLESTAKINGADDRESS

pub fun main(address: Address): {String: {UInt32: FlowIDTableStaking.DelegatorInfo}} {
    return StakingCollection.getAllDelegatorInfo(address: address)
}