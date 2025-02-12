import "FlowStakingCollection"

/// Tells how many locked tokens the account is using
/// For there staking collection nodes and delegators

access(all) fun main(account: Address): UFix64 {
    return FlowStakingCollection.getLockedTokensUsed(address: account)
}