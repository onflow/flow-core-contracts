import FlowStakingCollection from "FlowStakingCollection"

/// Tells how many unlocked tokens the account is using
/// For there staking collection nodes and delegators

access(all) fun main(account: Address): UFix64 {
    return FlowStakingCollection.getUnlockedTokensUsed(address: account)
}
