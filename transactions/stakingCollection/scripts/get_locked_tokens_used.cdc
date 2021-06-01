import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

/// Tells how many locked tokens the account is using
/// For there staking collection nodes and delegators

pub fun main(account: Address): UFix64 {
    return FlowStakingCollection.getLockedTokensUsed(address: account)
}