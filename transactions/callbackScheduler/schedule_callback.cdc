import "FlowCallbackScheduler"
import "TestFlowCallbackHandler"
import "FlowToken"
import "FungibleToken"

/// Schedules a callback for the TestFlowCallbackHandler contract
///
/// This is just an example transaction that uses an example contract
/// If you want to schedule your own callbacks, you need to develop your own contract
/// that has a resource that implements the FlowCallbackScheduler.CallbackHandler interface
/// that contains your custom code that should be executed when the callback is scheduled.
/// Your transaction will look similar to this one, but will use your custom contract and types
/// instead of TestFlowCallbackHandler

transaction(timestamp: UFix64, feeAmount: UFix64, effort: UInt64, priority: UInt8, testData: AnyStruct?) {

    prepare(account: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability, GetStorageCapabilityController) &Account) {
        
        // If a callback handler has not been created for this account yet, create one,
        // store it, and issue a capability that will be used to create the callback
        if !account.storage.check<@TestFlowCallbackHandler.Handler>(from: TestFlowCallbackHandler.HandlerStoragePath) {
            let handler <- TestFlowCallbackHandler.createHandler()
        
            account.storage.save(<-handler, to: TestFlowCallbackHandler.HandlerStoragePath)
            account.capabilities.storage.issue<auth(FlowCallbackScheduler.Execute) &{FlowCallbackScheduler.CallbackHandler}>(TestFlowCallbackHandler.HandlerStoragePath)
        }

        // Get the capability that will be used to create the callback
        let callbackCap = account.capabilities.storage
                            .getControllers(forPath: TestFlowCallbackHandler.HandlerStoragePath)[0]
                            .capability as! Capability<auth(FlowCallbackScheduler.Execute) &{FlowCallbackScheduler.CallbackHandler}>
        
        // borrow a reference to the vault that will be used for fees
        let vault = account.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow FlowToken vault")
        
        let fees <- vault.withdraw(amount: feeAmount) as! @FlowToken.Vault
        let priorityEnum = FlowCallbackScheduler.Priority(rawValue: priority)
            ?? FlowCallbackScheduler.Priority.High

        if let dataString = testData as? String {
            if dataString == "schedule" {
                // Schedule the callback that schedules another callback
                let scheduledCallback <- FlowCallbackScheduler.schedule(
                    callback: callbackCap,
                    data: callbackCap,
                    timestamp: timestamp,
                    priority: priorityEnum,
                    executionEffort: effort,
                    fees: <-fees
                )
                TestFlowCallbackHandler.addScheduledCallback(callback: <-scheduledCallback)
                return
            }
        }
        // Schedule the regular callback with the main contract
        let scheduledCallback <- FlowCallbackScheduler.schedule(
            callback: callbackCap,
            data: testData,
            timestamp: timestamp,
            priority: priorityEnum,
            executionEffort: effort,
            fees: <-fees
        )
        TestFlowCallbackHandler.addScheduledCallback(callback: <-scheduledCallback)
    }
} 
