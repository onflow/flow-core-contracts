transaction(contractName: String, code: String) {
    
    prepare(admin: AuthAccount) {
        admin.contracts.add(name: contractName, code: code.decodeHex())
    }
}
