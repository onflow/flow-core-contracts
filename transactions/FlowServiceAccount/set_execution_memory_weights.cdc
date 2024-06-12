// This transactions sets new execution memory weights.
transaction(newWeights: {UInt64: UInt64}) {
    prepare(signer: auth(Storage) &Account) {
        signer.storage.load<{UInt64: UInt64}>(from: /storage/executionMemoryWeights)
        signer.storage.save(newWeights, to: /storage/executionMemoryWeights)
    }
}