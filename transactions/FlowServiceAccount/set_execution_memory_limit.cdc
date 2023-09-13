// This transactions sets a new execution memory limit.
transaction(newLimit: UInt64) {
    prepare(signer: auth(Storage) &Account) {
        signer.storage.load<UInt64>(from: /storage/executionMemoryLimit)
        signer.storage.save(newLimit, to: /storage/executionMemoryLimit)
    }
}