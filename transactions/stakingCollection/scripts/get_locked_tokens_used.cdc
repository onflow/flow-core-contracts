import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

pub fun main(account: Address): UFix64 {
    return FlowStakingCollection.getLockedTokensUsed(address: account)
}