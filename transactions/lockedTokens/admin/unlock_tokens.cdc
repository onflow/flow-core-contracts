import LockedTokens from 0xf3fcd2c1a78f5eee

transaction(targetAccount: Address, delta: UFix64) {

    prepare(acct: AuthAccount) {

        let adminRef = acct.borrow<&LockedTokens.TokenAdminCollection>(from: LockedTokens.LockedTokenAdminCollectionStoragePath)
            ?? panic("Could not borrow a reference to the admin collection")

        let tokenManagerRef = adminRef.getAccount(address: targetAccount).borrow()
            ?? panic("Could not borrow a reference to the user's token manager")

        tokenManagerRef.increaseUnlockLimit(delta: delta)
    }
}
