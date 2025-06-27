import "CallbackScheduler"

// transaction to process callbacks
transaction {
    execute {
        CallbackScheduler.process()
    }
}