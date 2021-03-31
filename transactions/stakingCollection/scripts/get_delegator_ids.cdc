import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

pub fun main(address: Address): [FlowStakingCollection.DelegatorIDs] {
    return FlowStakingCollection.getDelegatorIDs(address: address)
}