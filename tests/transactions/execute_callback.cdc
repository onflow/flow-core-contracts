import "FlowCallbackScheduler"

transaction(ID: UInt64) {
    execute {
        FlowCallbackScheduler.executeCallback(id: ID)
    }
}