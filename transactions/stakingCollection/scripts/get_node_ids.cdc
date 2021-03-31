import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

pub fun main(address: Address): [String] {
    return FlowStakingCollection.getNodeIDs(address: address)
}