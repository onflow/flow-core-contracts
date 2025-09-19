import "FlowTransactionScheduler"
import "FlowTransactionSchedulerUtils"
import "TestFlowScheduledTransactionHandler"
import "FlowToken"
import "FungibleToken"

// ⚠️  WARNING: UNSAFE FOR PRODUCTION ⚠️
// This transaction uses a TEST CONTRACT and should NEVER be used in production!
// This transaction is designed solely for testing FlowTransactionScheduler functionality
// and contains unsafe implementations that could lead to loss of funds or security vulnerabilities.
//
// DO NOT USE THIS TRANSACTION IN PRODUCTION!
//
transaction(id: UInt64) {

    prepare(account: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability, GetStorageCapabilityController) &Account) {

        let manager = account.storage.borrow<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>(from: FlowTransactionSchedulerUtils.managerStoragePath)
            ?? panic("Could not borrow a Manager reference from \(FlowTransactionSchedulerUtils.managerStoragePath)")

        let vault = account.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow FlowToken vault")

        vault.deposit(from: <-manager.cancel(id: id))
    }
} 
