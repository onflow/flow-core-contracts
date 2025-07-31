import "FlowCallbackScheduler"

access(all) fun main(data: AnyStruct): UFix64 {
    return FlowCallbackScheduler.getSizeofData(data)
}
