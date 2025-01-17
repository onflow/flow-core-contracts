access(all) contract FlowExecutionParameters {
				
    // Gets Execution Effort Weights from the service account's storage
    access(all) view fun getExecutionEffortWeights(): {UInt64: UInt64} {
        return self.account.storage.copy<{UInt64: UInt64}>(from: /storage/executionEffortWeights)
            ?? panic("execution effort weights not set yet")
    }

    // Gets Execution Memory Weights from the service account's storage
    access(all) view fun getExecutionMemoryWeights(): {UInt64: UInt64} {
        return self.account.storage.copy<{UInt64: UInt64}>(from: /storage/executionMemoryWeights)
            ?? panic("execution memory weights not set yet")
    }

    // Gets Execution Memory Limit from the service account's storage
    access(all) view fun getExecutionMemoryLimit(): UInt64 {
        return self.account.storage.copy<UInt64>(from: /storage/executionMemoryLimit)
            ?? panic("execution memory limit not set yet")
    }
}