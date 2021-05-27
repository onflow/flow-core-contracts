import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

/// Gets all the machine account addresses for nodes
/// in the account's staking collection

pub fun main(account: Address): {String: FlowStakingCollection.MachineAccountInfo} {
    return FlowStakingCollection.getMachineAccounts(address: account)
}
