import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

pub fun main(address: Address): [StakingCollection.DelegatorIDs] {
    return StakingCollection.getDelegatorIDs(address: address)
}