// This transactions sets a new execution memory limit.
transaction(newLimit: UInt64) {
    prepare(signer: AuthAccount) {
        signer.load<{UInt64: UInt64}>(from: /storage/executionMemoryLimit)
        signer.save(newLimit, to: /storage/executionMemoryLimit)
    }
}