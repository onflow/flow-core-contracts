// Deploys a contract to an account
// Used to deploy the staking collection to the same account as the locked tokens contract

transaction(contractName: String, code: String) {
    
    prepare(admin: AuthAccount) {
        admin.contracts.add(name: contractName, code: code.decodeHex())
    }
}
