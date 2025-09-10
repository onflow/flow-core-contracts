import "FlowTransactionScheduler"

access(all) fun main(data: AnyStruct): UFix64 {
    return FlowTransactionScheduler.getSizeOfData(data)
}
