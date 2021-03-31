import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

pub fun main(address: Address): [StakingCollection.DelegatorIDs] {
    return FlowStakingCollection.getDelegatorIDs(address: address)
}