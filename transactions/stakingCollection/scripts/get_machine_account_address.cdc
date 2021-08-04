import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

/// Gets the machine account address for a specific node
/// in an account's staking collection

pub fun main(account: Address, nodeID: String): Address {
    let machineAccounts = FlowStakingCollection.getMachineAccounts(address: account)

    let accountInfo = machineAccounts[nodeID]
        ?? panic("Could not find machine account info for the specified node ID")

    return accountInfo.getAddress()
}
