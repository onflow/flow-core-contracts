import "FlowCallbackScheduler"
import "FlowCallbackUtils"
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

        // if a callback manager has not been created for this account yet, create one
        if !account.storage.check<@FlowCallbackUtils.CallbackManager>(from: FlowCallbackUtils.managerStoragePath) {
            let manager <- FlowCallbackUtils.createCallbackManager()
            account.storage.save(<-manager, to: FlowCallbackUtils.managerStoragePath)

            // create a public capability to the callback manager
            let managerRef = account.capabilities.storage.issue<&FlowCallbackUtils.CallbackManager>(FlowCallbackUtils.managerStoragePath)
            account.capabilities.publish(managerRef, at: FlowCallbackUtils.managerPublicPath)
        }
        
        // If a callback handler has not been created for this account yet, create one,
        // store it, and issue a capability that will be used to execute the callback
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

        // borrow a reference to the callback manager
        let manager = account.storage.borrow<auth(FlowCallbackUtils.Owner) &FlowCallbackUtils.CallbackManager>(from: FlowCallbackUtils.managerStoragePath)
            ?? panic("Could not borrow a CallbackManager reference from \(FlowCallbackUtils.managerStoragePath)")

        if let dataString = testData as? String {
            if dataString == "schedule" {
                // Schedule the callback that schedules another callback
                manager.schedule(
                    callback: callbackCap,
                    data: callbackCap,
                    timestamp: timestamp,
                    priority: priorityEnum,
                    executionEffort: effort,
                    fees: <-fees
                )
                return
            }
        }
        
        // Schedule the regular callback with the main contract
        manager.schedule(
            callback: callbackCap,
            data: testData,
            timestamp: timestamp,
            priority: priorityEnum,
            executionEffort: effort,
            fees: <-fees
        )
    }
} 
