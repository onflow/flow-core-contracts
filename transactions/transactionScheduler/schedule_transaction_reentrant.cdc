import "FlowTransactionScheduler"
import "FlowTransactionSchedulerUtils"
import "TestFlowScheduledTransactionHandler"
import "FlowToken"
import "FungibleToken"

// This transaction uses a TEST CONTRACT and shouldn't be directly used in production!
// This transaction is designed solely for testing FlowTransactionScheduler functionality
// and contains implementations that are specific to the tests
//
/// Schedules a transaction using the malicious TestFlowScheduledTransactionHandler.ReentrantHandler
/// whose resolveView() attempts to reenter schedule() while this schedule call is in flight,
/// in order to test that the per-slot effort limit cannot be bypassed via reentrancy.

transaction(timestamp: UFix64, feeAmount: UFix64, effort: UInt64, priority: UInt8) {

    prepare(account: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability, GetStorageCapabilityController) &Account) {

        // if a transaction scheduler manager has not been created for this account yet, create one
        if !account.storage.check<@{FlowTransactionSchedulerUtils.Manager}>(from: FlowTransactionSchedulerUtils.managerStoragePath) {
            let manager <- FlowTransactionSchedulerUtils.createManager()
            account.storage.save(<-manager, to: FlowTransactionSchedulerUtils.managerStoragePath)

            // create a public capability to the callback manager
            let managerRef = account.capabilities.storage.issue<&{FlowTransactionSchedulerUtils.Manager}>(FlowTransactionSchedulerUtils.managerStoragePath)
            account.capabilities.publish(managerRef, at: FlowTransactionSchedulerUtils.managerPublicPath)
        }

        // If a reentrant transaction handler has not been created for this account yet, create one,
        // store it, and issue a capability that will be used to create the transaction
        if !account.storage.check<@TestFlowScheduledTransactionHandler.ReentrantHandler>(from: TestFlowScheduledTransactionHandler.ReentrantHandlerStoragePath) {
            let handler <- TestFlowScheduledTransactionHandler.createReentrantHandler()

            account.storage.save(<-handler, to: TestFlowScheduledTransactionHandler.ReentrantHandlerStoragePath)
            account.capabilities.storage.issue<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>(TestFlowScheduledTransactionHandler.ReentrantHandlerStoragePath)

            let publicHandlerCap = account.capabilities.storage.issue<&{FlowTransactionScheduler.TransactionHandler}>(TestFlowScheduledTransactionHandler.ReentrantHandlerStoragePath)
            account.capabilities.publish(publicHandlerCap, at: TestFlowScheduledTransactionHandler.ReentrantHandlerPublicPath)
        }

        // Get the entitled capability that will be used to create the transaction
        var handlerCap: Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>? = nil

        for controller in account.capabilities.storage.getControllers(forPath: TestFlowScheduledTransactionHandler.ReentrantHandlerStoragePath) {
            if let cap = controller.capability as? Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}> {
                handlerCap = cap
                break
            }
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

        // Schedule the transaction with the malicious reentrant handler
        manager.schedule(
            handlerCap: handlerCap!,
            data: nil,
            timestamp: timestamp,
            priority: priorityEnum,
            executionEffort: effort,
            fees: <-fees
        )
    }
}
