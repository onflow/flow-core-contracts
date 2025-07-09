import "FlowCallbackScheduler"
import "TestFlowCallbackHandler"
import "FlowToken"
import "FungibleToken"

transaction(timestamp: UFix64, feeAmount: UFix64, effort: UInt64, priority: UInt8, testData: String) {

    prepare(account: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability, GetStorageCapabilityController) &Account) {
        if !account.storage.check<@TestFlowCallbackHandler.Handler>(from: TestFlowCallbackHandler.HandlerStoragePath) {
            let handler <- TestFlowCallbackHandler.createHandler()
        
            account.storage.save(<-handler, to: TestFlowCallbackHandler.HandlerStoragePath)
            account.capabilities.storage.issue<auth(FlowCallbackScheduler.ExecuteCallback) &{FlowCallbackScheduler.CallbackHandler}>(TestFlowCallbackHandler.HandlerStoragePath)
        }

        let callbackCap = account.capabilities.storage
                            .getControllers(forPath: TestFlowCallbackHandler.HandlerStoragePath)[0]
                            .capability as! Capability<auth(FlowCallbackScheduler.ExecuteCallback) &{FlowCallbackScheduler.CallbackHandler}>
        
        let vault = account.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
        ?? panic("Could not borrow FlowToken vault")
        
        let fees <- vault.withdraw(amount: feeAmount) as! @FlowToken.Vault
        let priorityEnum = FlowCallbackScheduler.Priority(rawValue: priority)
            ?? FlowCallbackScheduler.Priority.High

        let scheduledCallback = FlowCallbackScheduler.schedule(
            callback: callbackCap,
            data: testData,
            timestamp: timestamp,
            priority: priorityEnum,
            executionEffort: effort,
            fees: <-fees
        )

        TestFlowCallbackHandler.addScheduledCallback(callback: scheduledCallback)
    }
} 
