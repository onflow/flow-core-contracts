import "FlowStakingCollection"

/// Returns an array of all the delegator IDs stored in the staking collection

access(all) fun main(address: Address): [FlowStakingCollection.DelegatorIDs] {
    return FlowStakingCollection.getDelegatorIDs(address: address)
}