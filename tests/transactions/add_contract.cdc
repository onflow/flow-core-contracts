transaction(name: String, code: String) {
    prepare(account: auth(AddContract) &Account) {
        // Add the contract
        account.contracts.add(name: name, code: code.utf8)
    }
}
