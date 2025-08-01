import "FlowCallbackScheduler"
import "FlowToken"
import "FungibleToken"

// TestFlowCallbackHandler is a simplified test contract for testing CallbackScheduler
access(all) contract TestFlowCallbackHandler {
    access(all) var scheduledCallbacks: {UInt64: FlowCallbackScheduler.ScheduledCallback}
    access(all) var executedCallbacks: [UInt64]

    access(all) let HandlerStoragePath: StoragePath
    access(all) let HandlerPublicPath: PublicPath
    
    access(all) resource Handler: FlowCallbackScheduler.CallbackHandler {
        
        access(FlowCallbackScheduler.Execute) 
        fun executeCallback(id: UInt64, data: AnyStruct?) {
            // Most callbacks will have string data
            if let dataString = data as? String {
                // intentional failure test case
                if dataString == "fail" {
                    panic("Callback \(id) failed")
                } else {
                    // All other regular test cases should succeed
                    TestFlowCallbackHandler.executedCallbacks.append(id)
                }
            } else if let dataCap = data as? Capability<auth(FlowCallbackScheduler.Execute) &{FlowCallbackScheduler.CallbackHandler}> {
                // Testing scheduling a callback with a callback
                let scheduledCallback = FlowCallbackScheduler.schedule(
                    callback: dataCap,
                    data: "test data",
                    timestamp: getCurrentBlock().timestamp + 10.0,
                    priority: FlowCallbackScheduler.Priority.High,
                    executionEffort: UInt64(1000),
                    fees: <-TestFlowCallbackHandler.getFeeFromVault(amount: 1.0)
                )
                TestFlowCallbackHandler.addScheduledCallback(callback: scheduledCallback)
            } else {
                panic("TestFlowCallbackHandler.executeCallback: Invalid data type for callback with id \(id). Type is \(data.getType().identifier)")
            }
        }
    }

    access(all) fun createHandler(): @Handler {
        return <- create Handler()
    }

    access(all) fun addScheduledCallback(callback: FlowCallbackScheduler.ScheduledCallback) {
        self.scheduledCallbacks[callback.id] = callback
    }

    access(all) fun cancelCallback(id: UInt64): @FlowToken.Vault {
        let callback = self.scheduledCallbacks[id]
            ?? panic("Invalid ID: \(id) callback not found")
        self.scheduledCallbacks[id] = nil
        return <-FlowCallbackScheduler.cancel(callback: callback)
    }

    access(all) fun getExecutedCallbacks(): [UInt64] {
        return self.executedCallbacks
    }

    access(contract) fun getFeeFromVault(amount: UFix64): @FlowToken.Vault {
        // borrow a reference to the vault that will be used for fees
        let vault = self.account.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow FlowToken vault")
        
        return <- vault.withdraw(amount: amount) as! @FlowToken.Vault
    }

    access(all) init() {
        self.scheduledCallbacks = {}
        self.executedCallbacks = []

        self.HandlerStoragePath = /storage/testCallbackHandler
        self.HandlerPublicPath = /public/testCallbackHandler
    }
} 