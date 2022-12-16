import FlowStorageFees from 0xFLOWSTORAGEFEESADDRESS

pub fun main(accountAddresses: [Address], payer: Address, maxTxFees: UFix64): [UFix64] {
    return FlowStorageFees.getAccountsCapacityForTransactionStorageCheck(
        accountAddresses: accountAddresses, 
        payer: payer, 
        maxTxFees: maxTxFees)
}