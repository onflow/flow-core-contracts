import "FlowCallbackScheduler"

// TestFlowCallbackHandler is a simplified test contract for testing CallbackScheduler
access(all) contract TestFlowCallbackHandler {
    access(all) var scheduledCallbacks: [FlowCallbackScheduler.ScheduledCallback]
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
        self.scheduledCallbacks.append(callback)
    }

    access(all) fun getExecutedCallbacks(): [UInt64] {
        return self.executedCallbacks
    }

    access(all) init() {
        self.scheduledCallbacks = []
        self.executedCallbacks = []

        self.HandlerStoragePath = /storage/testCallbackHandler
        self.HandlerPublicPath = /public/testCallbackHandler
    }
} 