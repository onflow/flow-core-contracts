import "TestFlowCallbackHandler"
import "FlowCallbackScheduler"

transaction {
    prepare(account: auth(BorrowValue, LoadValue) &Account) {
        let handler <- account.storage.load<@TestFlowCallbackHandler.Handler>(from: TestFlowCallbackHandler.HandlerStoragePath)
            ?? panic("Could not load TestFlowCallbackHandler")
        destroy handler
    }
}

