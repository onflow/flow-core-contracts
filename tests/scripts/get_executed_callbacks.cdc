import "TestFlowCallbackHandler"

access(all) fun main(): [UInt64] {
    return TestFlowCallbackHandler.getExecutedCallbacks()
}
