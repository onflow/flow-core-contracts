import "CallbackScheduler"
import "TestCallbackHandler"
import "FlowToken"
import "FungibleToken"

transaction(timestamp: UFix64, feeAmount: UFix64, priority: UInt8, testData: String) {

    prepare(account: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability) &Account) {
        let handler <- TestCallbackHandler.createHandler()
        
        account.storage.save(<-handler, to: TestCallbackHandler.HandlerStoragePath)
        let callbackCap = account.capabilities.storage.issue<auth(CallbackScheduler.mayExecuteCallback) &{CallbackScheduler.CallbackHandler}>(TestCallbackHandler.HandlerStoragePath)
        
        let vault = account.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
        ?? panic("Could not borrow FlowToken vault")
        
        let fees <- vault.withdraw(amount: feeAmount) as! @FlowToken.Vault
        let priorityEnum = priority == 0 ? CallbackScheduler.Priority.Low : 
                          priority == 1 ? CallbackScheduler.Priority.Medium : 
                          CallbackScheduler.Priority.High

        let scheduledCallback = CallbackScheduler.schedule(
            callback: callbackCap,
            data: testData,
            timestamp: timestamp,
            priority: priorityEnum,
            executionEffort: 1000,
            fees: <-fees
        )

        TestCallbackHandler.addScheduledCallback(callback: scheduledCallback)
    }
} 
