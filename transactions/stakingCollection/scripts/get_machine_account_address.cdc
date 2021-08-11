import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

/// Gets the machine account address for a specific node
/// in an account's staking collection

pub fun main(account: Address, nodeID: String): Address? {
    let machineAccounts = FlowStakingCollection.getMachineAccounts(address: account)

    if let accountInfo = machineAccounts[nodeID] {
        return accountInfo.getAddress()
    } else {
        return nil
    }
}
