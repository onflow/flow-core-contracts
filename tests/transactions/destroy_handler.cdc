import "TestFlowScheduledTransactionHandler"
import "FlowTransactionScheduler"

transaction {
    prepare(account: auth(BorrowValue, LoadValue) &Account) {
        let handler <- account.storage.load<@TestFlowScheduledTransactionHandler.Handler>(from: TestFlowScheduledTransactionHandler.HandlerStoragePath)
            ?? panic("Could not load TestFlowScheduledTransactionHandler")
        destroy handler
    }
}

