import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

/// Check if an account is set up with a Staking Collection

pub fun main(address: Address): Bool {
    return FlowStakingCollection.checkStakingCollection(address: address)
}