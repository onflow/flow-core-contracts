transaction(contractName: String, code: String, publicKeys: [[UInt8]]) {
    
    prepare(admin: AuthAccount) {
        let lockedTokens = AuthAccount(payer: admin)
        lockedTokens.contracts.add(name: contractName, code: code.decodeHex(), admin)

        for key in publicKeys {
            lockedTokens.addPublicKey(key)
        }
    }
}
