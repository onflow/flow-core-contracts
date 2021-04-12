import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

/// Tells how many unlocked tokens the account is using
/// For there staking collection nodes and delegators

pub fun main(account: Address): UFix64 {
    return FlowStakingCollection.getUnlockedTokensUsed(address: account)
}
