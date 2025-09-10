import "FlowTransactionScheduler"
import "TestFlowScheduledTransactionHandler"
import "FlowToken"
import "FungibleToken"

transaction(id: UInt64) {

    prepare(account: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability, GetStorageCapabilityController) &Account) {

        let vault = account.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow FlowToken vault")

        vault.deposit(from: <-TestFlowScheduledTransactionHandler.cancelTransaction(id: id))
    }
} 
