import "FlowTransactionScheduler"
import "FlowTransactionSchedulerUtils"
import "FlowToken"
import "FungibleToken"

// This transaction uses a TEST CONTRACT and shouldn't be directly used in production!
// This transaction is designed solely for testing FlowTransactionScheduler functionality
// and contains implementations that are specific to the tests
//
// Replace this transaction with your own implementation when using FlowTransactionScheduler
//
/// Schedules a transaction for the FlowTransactionSchedulerUtils.Manager for an existing handler
/// that has been used by the manager before
///
/// @param handlerTypeIdentifier: The type identifier of the handler
/// @param handlerUUID: The UUID of the handler
/// @param timestamp: The timestamp when the transaction should be executed
/// @param feeAmount: The fee amount for the transaction

transaction(handlerTypeIdentifier: String, handlerUUID: UInt64?, timestamp: UFix64, feeAmount: UFix64, effort: UInt64, priority: UInt8, testData: AnyStruct?) {

    prepare(account: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability, GetStorageCapabilityController) &Account) {
        
        // borrow a reference to the vault that will be used for fees
        let vault = account.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow FlowToken vault")
        
        let fees <- vault.withdraw(amount: feeAmount) as! @FlowToken.Vault
        let priorityEnum = FlowTransactionScheduler.Priority(rawValue: priority)
            ?? FlowTransactionScheduler.Priority.High

        // borrow a reference to the callback manager
        let manager = account.storage.borrow<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>(from: FlowTransactionSchedulerUtils.managerStoragePath)
            ?? panic("Could not borrow a Manager reference from \(FlowTransactionSchedulerUtils.managerStoragePath)")

        // Schedule the regular transaction with the main contract
        manager.scheduleByHandler(
            handlerTypeIdentifier: handlerTypeIdentifier,
            handlerUUID: handlerUUID,
            data: testData,
            timestamp: timestamp,
            priority: priorityEnum,
            executionEffort: effort,
            fees: <-fees
        )
    }
} 
