import "FlowCallbackScheduler"
import "FlowCallbackUtils"
import "FlowToken"
import "FungibleToken"

// TestFlowCallbackHandler is a simplified test contract for testing CallbackScheduler
access(all) contract TestFlowCallbackHandler {
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

        access(all) view fun getViews(): [Type] {
            return []
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            return nil
        }
        
        access(FlowCallbackScheduler.Execute) 
        fun executeCallback(id: UInt64, data: AnyStruct?) {
            // Most callbacks will have string data
            if let dataString = data as? String {
                // intentional failure test case
                if dataString == "fail" {
                    panic("Callback \(id) failed")
                } else if dataString == "cancel" {
                    let manager = TestFlowCallbackHandler.borrowManager()
                    // This should always fail because the callback can't cancel itself during execution
                    destroy <-manager.cancel(id: id)
                } else {
                    // All other regular test cases should succeed
                    TestFlowCallbackHandler.succeededCallbacks.append(id)
                }
            } else if let dataCap = data as? Capability<auth(FlowCallbackScheduler.Execute) &{FlowCallbackScheduler.CallbackHandler}> {
                // Testing scheduling a callback with a callback
                let manager = TestFlowCallbackHandler.borrowManager()
                manager.schedule(
                    callback: dataCap,
                    data: "test data",
                    timestamp: getCurrentBlock().timestamp + 10.0,
                    priority: FlowCallbackScheduler.Priority.High,
                    executionEffort: UInt64(1000),
                    fees: <-TestFlowCallbackHandler.getFeeFromVault(amount: 1.0)
                )
            } else {
                panic("TestFlowCallbackHandler.executeCallback: Invalid data type for callback with id \(id). Type is \(data.getType().identifier)")
            }
        }
    }

    access(all) fun createHandler(): @Handler {
        return <- create Handler(name: "Test FlowCallbackHandler Resource", description: "Executes a variety of callbacks for different test cases")
    }

    access(all) fun getSucceededCallbacks(): [UInt64] {
        return self.succeededCallbacks
    }

    access(all) fun borrowManager(): auth(FlowCallbackUtils.Owner) &FlowCallbackUtils.CallbackManager {
        return self.account.storage.borrow<auth(FlowCallbackUtils.Owner) &FlowCallbackUtils.CallbackManager>(from: FlowCallbackUtils.managerStoragePath)
            ?? panic("Callback manager not set")
    }

    access(all) fun getCallbackIDs(): [UInt64] {
        let manager = self.borrowManager()
        return manager.getCallbackIDs()
    }

    access(all) fun getCallbackStatus(id: UInt64): FlowCallbackScheduler.Status? {
        let manager = self.borrowManager()
        return manager.getCallbackStatus(id: id)
    }

    access(contract) fun getFeeFromVault(amount: UFix64): @FlowToken.Vault {
        // borrow a reference to the vault that will be used for fees
        let vault = self.account.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow FlowToken vault")
        
        return <- vault.withdraw(amount: amount) as! @FlowToken.Vault
    }

    access(all) init() {
        self.succeededCallbacks = []

        self.HandlerStoragePath = /storage/testCallbackHandler
        self.HandlerPublicPath = /public/testCallbackHandler
    }
} 