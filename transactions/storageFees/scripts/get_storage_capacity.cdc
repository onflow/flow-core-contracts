import FlowStorageFees from 0xFLOWSTORAGEFEESADDRESS

pub fun main(accountAddress: Address): UFix64 {
    return FlowStorageFees.calculateAccountCapacity(accountAddress)
}

