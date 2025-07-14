import "FlowCallbackScheduler"
import "FlowToken"

// TestFlowCallbackHandler is a simplified test contract for testing CallbackScheduler
access(all) contract TestFlowCallbackHandler {
    access(all) var scheduledCallbacks: {UInt64: FlowCallbackScheduler.ScheduledCallback}
    access(all) var executedCallbacks: [UInt64]

    access(all) let HandlerStoragePath: StoragePath
    access(all) let HandlerPublicPath: PublicPath
    
    access(all) resource Handler: FlowCallbackScheduler.CallbackHandler {
        
        access(FlowCallbackScheduler.ExecuteCallback) 
        fun executeCallback(id: UInt64, data: AnyStruct?) {
            TestFlowCallbackHandler.executedCallbacks.append(id)
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

    access(all) init() {
        self.scheduledCallbacks = {}
        self.executedCallbacks = []

        self.HandlerStoragePath = /storage/testCallbackHandler
        self.HandlerPublicPath = /public/testCallbackHandler
    }
} 