import "FlowTransactionScheduler"
import "TestFlowScheduledTransactionHandler"
import "FlowToken"
import "FungibleToken"

/// Schedules a transaction for the TestFlowScheduledTransactionHandler contract
///
/// This is just an example transaction that uses an example contract
/// If you want to schedule your own transactions, you need to develop your own contract
/// that has a resource that implements the FlowTransactionScheduler.TransactionHandler interface
/// that contains your custom code that should be executed when the transaction is scheduled.
/// Your transaction will look similar to this one, but will use your custom contract and types
/// instead of TestFlowScheduledTransactionHandler

transaction(timestamp: UFix64, feeAmount: UFix64, effort: UInt64, priority: UInt8, testData: AnyStruct?) {

    prepare(account: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability, GetStorageCapabilityController) &Account) {
        
        // If a transaction handler has not been created for this account yet, create one,
        // store it, and issue a capability that will be used to create the transaction
        if !account.storage.check<@TestFlowScheduledTransactionHandler.Handler>(from: TestFlowScheduledTransactionHandler.HandlerStoragePath) {
            let handler <- TestFlowScheduledTransactionHandler.createHandler()
        
            account.storage.save(<-handler, to: TestFlowScheduledTransactionHandler.HandlerStoragePath)
            account.capabilities.storage.issue<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>(TestFlowScheduledTransactionHandler.HandlerStoragePath)
        }

        // Get the capability that will be used to create the transaction
        let handlerCap = account.capabilities.storage
                            .getControllers(forPath: TestFlowScheduledTransactionHandler.HandlerStoragePath)[0]
                            .capability as! Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>
        
        // borrow a reference to the vault that will be used for fees
        let vault = account.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow FlowToken vault")
        
        let fees <- vault.withdraw(amount: feeAmount) as! @FlowToken.Vault
        let priorityEnum = FlowTransactionScheduler.Priority(rawValue: priority)
            ?? FlowTransactionScheduler.Priority.High

        if let dataString = testData as? String {
            if dataString == "schedule" {
                // Schedule the transaction that schedules another transaction
                let scheduledTransaction <- FlowTransactionScheduler.schedule(
                    handlerCap: handlerCap,
                    data: handlerCap,
                    timestamp: timestamp,
                    priority: priorityEnum,
                    executionEffort: effort,
                    fees: <-fees
                )
                TestFlowScheduledTransactionHandler.addScheduledTransaction(scheduledTx: <-scheduledTransaction)
                return
            }
        }
        // Schedule the regular transaction with the main contract
        let scheduledTransaction <- FlowTransactionScheduler.schedule(
            handlerCap: handlerCap,
            data: testData,
            timestamp: timestamp,
            priority: priorityEnum,
            executionEffort: effort,
            fees: <-fees
        )
        TestFlowScheduledTransactionHandler.addScheduledTransaction(scheduledTx: <-scheduledTransaction)
    }
} 
