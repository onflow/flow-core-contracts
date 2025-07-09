import "FlowCallbackScheduler"

// transaction to process callbacks
transaction {
    execute {
        FlowCallbackScheduler.process()
    }
}