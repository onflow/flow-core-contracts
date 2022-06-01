// This transactions sets new execution memory weights.
transaction(newWeights: {UInt64: UInt64}) {
    prepare(signer: AuthAccount) {
        signer.load<{UInt64: UInt64}>(from: /storage/executionMemoryWeights)
        signer.save(newWeights, to: /storage/executionMemoryWeights)
    }
}