import "TestFlowScheduledTransactionHandler"

access(all) fun main(): [UInt64] {
    return TestFlowScheduledTransactionHandler.getSucceededTransactions()
}
