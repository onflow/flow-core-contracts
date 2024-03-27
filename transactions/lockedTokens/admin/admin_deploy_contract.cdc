import Crypto

transaction(contractName: String, code: String, publicKeys: [Crypto.KeyListEntry]) {
    
    prepare(admin: auth(Storage, BorrowValue) &Account) {
        let lockedTokens = Account(payer: admin)
        lockedTokens.contracts.add(name: contractName, code: code.decodeHex(), admin)

        for key in publicKeys {
            lockedTokens.keys.add(publicKey: key.publicKey, hashAlgorithm: key.hashAlgorithm, weight: key.weight)
        }
    }
}
