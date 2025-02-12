import "FlowStorageFees"

access(all) fun main(accountAddress: Address): UFix64 {
    return FlowStorageFees.defaultTokenAvailableBalance(accountAddress)
}

