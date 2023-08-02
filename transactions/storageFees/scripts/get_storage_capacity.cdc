import FlowStorageFees from 0xFLOWSTORAGEFEESADDRESS

access(all) fun main(accountAddress: Address): UFix64 {
    return FlowStorageFees.calculateAccountCapacity(accountAddress)
}

