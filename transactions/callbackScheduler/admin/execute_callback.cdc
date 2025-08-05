import "FlowCallbackScheduler"

transaction(id: UInt64) {
    execute {
        log("[system.execute_callback] executing callback \(id)")
        FlowCallbackScheduler.executeCallback(id: id)
    }
}