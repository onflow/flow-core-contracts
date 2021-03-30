import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

pub fun main(address: Address): [String] {
    return StakingCollection.getNodeIDs(address: address)
}