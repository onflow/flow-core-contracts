import "CallbackScheduler"

transaction(ID: UInt64) {
    execute {
        CallbackScheduler.executeCallback(ID: ID)
    }
}