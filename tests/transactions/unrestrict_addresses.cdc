transaction(addressesToUnrestrict: [Address]) {
    prepare(account: auth(Storage) &Account) {
        // load old restricted accounts
        var restrictedAccounts = account.storage.load<[Address]>(from: /storage/restrictedAccounts)
            ?? panic("Could not load restricted accounts")

        let lengthBefore = restrictedAccounts.length
            
        // remove addresses to unrestrict from restricted accounts
        for addressToUnrestrict in addressesToUnrestrict {
            restrictedAccounts.remove(at: restrictedAccounts.firstIndex(of: addressToUnrestrict)!)
        }

        let lengthAfter = restrictedAccounts.length

        assert(
            lengthAfter == lengthBefore - addressesToUnrestrict.length,
            message: "Length of restricted accounts after removal should equal to the length before minus the number of addresses to unrestrict."
        )

        for addressToUnrestrict in addressesToUnrestrict {
            assert(
                restrictedAccounts.firstIndex(of:addressToUnrestrict) == nil,
                message: "Address \(addressToUnrestrict) is still in the restricted accounts list but should have been removed."
            )
        }

        // set new
        account.storage.save(restrictedAccounts, to: /storage/restrictedAccounts)
    }
}