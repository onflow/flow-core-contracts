import "FlowCallbackScheduler"

transaction(id: UInt64) {
    execute {
        FlowCallbackScheduler.executeCallback(id: id)
    }
}