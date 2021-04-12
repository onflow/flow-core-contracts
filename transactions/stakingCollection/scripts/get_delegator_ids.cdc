import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

/// Returns an array of all the delegator IDs stored in the staking collection

pub fun main(address: Address): [FlowStakingCollection.DelegatorIDs] {
    return FlowStakingCollection.getDelegatorIDs(address: address)
}