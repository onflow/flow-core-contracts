import FlowStakingCollection from "FlowStakingCollection"

/// Determines if an account is set up with a Staking Collection

access(all) fun main(address: Address): Bool {
    return FlowStakingCollection.doesAccountHaveStakingCollection(address: address)
}