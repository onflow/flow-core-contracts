import "FlowCallbackScheduler"

// transaction to process callbacks
transaction {
    execute {
        log("[system.process_callbacks] processing callbacks")
        FlowCallbackScheduler.process()
    }
}