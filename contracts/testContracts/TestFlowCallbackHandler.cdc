import "FlowCallbackScheduler"

// TestFlowCallbackHandler is a simplified test contract for testing CallbackScheduler
access(all) contract TestFlowCallbackHandler {
    access(all) var scheduledCallbacks: [FlowCallbackScheduler.ScheduledCallback]
    access(all) var executedCallback: UInt64

    access(all) let HandlerStoragePath: StoragePath
    access(all) let HandlerPublicPath: PublicPath
    
    access(all) resource Handler: FlowCallbackScheduler.CallbackHandler {
        
        access(FlowCallbackScheduler.ExecuteCallback) 
        fun executeCallback(id: UInt64, data: AnyStruct?) {
            TestFlowCallbackHandler.executedCallback = id
        }
    }

    access(all) fun createHandler(): @Handler {
        return <- create Handler()
    }

    access(all) fun addScheduledCallback(callback: FlowCallbackScheduler.ScheduledCallback) {
        self.scheduledCallbacks.append(callback)
    }

    access(all) init() {
        self.scheduledCallbacks = []
        self.executedCallback = 0

        self.HandlerStoragePath = /storage/testCallbackHandler
        self.HandlerPublicPath = /public/testCallbackHandler
    }
} 