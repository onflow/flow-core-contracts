import FlowStakingCollection from "FlowStakingCollection"

/// Gets all the machine account addresses for nodes
/// in the account's staking collection

access(all) fun main(account: Address): {String: FlowStakingCollection.MachineAccountInfo} {
    return FlowStakingCollection.getMachineAccounts(address: account)
}
