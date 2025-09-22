import "FlowTransactionScheduler"
import "FlowTransactionSchedulerUtils"
import "TestFlowScheduledTransactionHandler"
import "FlowToken"
import "FungibleToken"

// This transaction uses a TEST CONTRACT and tests different non-standard handler types
// It shouldn't be directly used in production!
// This transaction is designed solely for testing FlowTransactionScheduler functionality
// and contains implementations that are specific to the tests
//
// Replace this transaction with your own implementation when using FlowTransactionScheduler
//

transaction(timestamp: UFix64, feeAmount: UFix64, effort: UInt64, priority: UInt8, testData: AnyStruct?) {

    prepare(account: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability, GetStorageCapabilityController) &Account) {
        
        // If a transaction handler has not been created for this account yet, create one,
        // store it, and issue a capability that will be used to create the transaction
        if !account.storage.check<@TestFlowScheduledTransactionHandler.Handler>(from: /storage/secondTestHandler) {
            let handler <- TestFlowScheduledTransactionHandler.createHandler()
        
            account.storage.save(<-handler, to: /storage/secondTestHandler)
            account.capabilities.storage.issue<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>(/storage/secondTestHandler)
            
            let publicHandlerCap = account.capabilities.storage.issue<&{FlowTransactionScheduler.TransactionHandler}>(/storage/secondTestHandler)
            account.capabilities.publish(publicHandlerCap, at: /public/secondTestHandler)
        }

        // Get the entitled capability that will be used to create the transaction
        // Need to check both controllers because the order of controllers is not guaranteed
        var handlerCap: Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>? = nil
        
        if let cap = account.capabilities.storage
                            .getControllers(forPath: /storage/secondTestHandler)[0]
                            .capability as? Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}> {
            handlerCap = cap
        } else {
            handlerCap = account.capabilities.storage
                            .getControllers(forPath: /storage/secondTestHandler)[1]
                            .capability as! Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>
        }
        
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
        manager.schedule(
            handlerCap: handlerCap!,
            data: testData,
            timestamp: timestamp,
            priority: priorityEnum,
            executionEffort: effort,
            fees: <-fees
        )
    }
} 
