import StakingCollection from 0xSTAKINGCOLLECTION

pub fun main(address: Address): [String] {
    return StakingCollection.getNodeIDs(address: address)
}