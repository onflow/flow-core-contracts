import "CallbackScheduler"

// TestCallbackHandler is a simplified test contract for testing CallbackScheduler
access(all) contract TestCallbackHandler {
    access(all) var scheduledCallbacks: [CallbackScheduler.ScheduledCallback]
    access(all) var executedCallback: UInt64

    access(all) let HandlerStoragePath: StoragePath
    access(all) let HandlerPublicPath: PublicPath
    
    access(all) resource Handler: CallbackScheduler.CallbackHandler {
        
        access(CallbackScheduler.mayExecuteCallback) 
        fun executeCallback(ID: UInt64, data: AnyStruct?) {
            TestCallbackHandler.executedCallback = ID
        }
    }

    access(all) fun createHandler(): @Handler {
        return <- create Handler()
    }

    access(all) fun addScheduledCallback(callback: CallbackScheduler.ScheduledCallback) {
        self.scheduledCallbacks.append(callback)
    }

    access(all) init() {
        self.scheduledCallbacks = []
        self.executedCallback = 0

        self.HandlerStoragePath = /storage/testCallbackHandler
        self.HandlerPublicPath = /public/testCallbackHandler
    }
} 