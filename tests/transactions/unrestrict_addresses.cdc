transaction(addressesToUnrestrict: [Address]) {
    prepare(account: auth(Storage) &Account) {
        // load old restricted accounts
        var restrictedAccounts = account.storage.load<[Address]>(from: /storage/restrictedAccounts)
            ?? panic("Could not load restricted accounts")
            
        // remove addresses to unrestrict from restricted accounts
        for addressToUnrestrict in addressesToUnrestrict {
            restrictedAccounts.remove(at: restrictedAccounts.firstIndex(of: addressToUnrestrict)!)
        }

        // set new
        account.storage.save(restrictedAccounts, to: /storage/restrictedAccounts)
    }
}