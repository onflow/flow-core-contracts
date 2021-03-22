import StakingCollection from 0xSTAKINGCOLLECTION

pub fun main(address: Address): [StakingCollection.DelegatorIDs] {
    return StakingCollection.getDelegatorIDs(address: address)
}