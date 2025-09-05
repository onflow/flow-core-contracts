import "FlowCallbackScheduler"
import "FlowToken"
import "FungibleToken"

// TestFlowCallbackHandler is a simplified test contract for testing CallbackScheduler
access(all) contract TestFlowCallbackHandler {
    access(all) var scheduledCallbacks: {UInt64: FlowCallbackScheduler.ScheduledCallback}
    access(all) var succeededCallbacks: [UInt64]

    access(all) let HandlerStoragePath: StoragePath
    access(all) let HandlerPublicPath: PublicPath
    
    access(all) resource Handler: FlowCallbackScheduler.CallbackHandler {

        access(all) let name: String
        access(all) let description: String

        init(name: String, description: String) {
            self.name = name
            self.description = description
        }
        
        access(FlowCallbackScheduler.Execute) 
        fun executeCallback(id: UInt64, data: AnyStruct?) {
            // Most callbacks will have string data
            if let dataString = data as? String {
                // intentional failure test case
                if dataString == "fail" {
                    panic("Callback \(id) failed")
                } else if dataString == "cancel" {
                    // This should always fail because the callback can't cancel itself during execution
                    destroy <-TestFlowCallbackHandler.cancelCallback(id: id)
                } else {
                    // All other regular test cases should succeed
                    TestFlowCallbackHandler.succeededCallbacks.append(id)
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
        return <- create Handler(name: "Test FlowCallbackHandler Resource", description: "Executes a variety of callbacks for different test cases")
    }

    access(all) fun addScheduledCallback(callback: FlowCallbackScheduler.ScheduledCallback) {
        let status = callback.status()
        if status == nil {
            panic("Invalid status for callback with id \(callback.id)")
        }
        self.scheduledCallbacks[callback.id] = callback
    }

    access(all) fun cancelCallback(id: UInt64): @FlowToken.Vault {
        let callback = self.scheduledCallbacks[id]
            ?? panic("Invalid ID: \(id) callback not found")
        self.scheduledCallbacks[id] = nil
        return <-FlowCallbackScheduler.cancel(callback: callback)
    }

    access(all) fun getSucceededCallbacks(): [UInt64] {
        return self.succeededCallbacks
    }

    access(contract) fun getFeeFromVault(amount: UFix64): @FlowToken.Vault {
        // borrow a reference to the vault that will be used for fees
        let vault = self.account.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow FlowToken vault")
        
        return <- vault.withdraw(amount: amount) as! @FlowToken.Vault
    }

    access(all) init() {
        self.scheduledCallbacks = {}
        self.succeededCallbacks = []

        self.HandlerStoragePath = /storage/testCallbackHandler
        self.HandlerPublicPath = /public/testCallbackHandler
    }
} 