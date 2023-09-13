import LockedTokens from 0xLOCKEDTOKENADDRESS

transaction(targetAccount: Address, delta: UFix64) {

    prepare(admin: auth(BorrowValue) &Account) {

        let adminRef = admin.storage.borrow<&LockedTokens.TokenAdminCollection>(from: LockedTokens.LockedTokenAdminCollectionStoragePath)
            ?? panic("Could not borrow a reference to the admin collection")

        let tokenManagerRef = adminRef.getAccount(address: targetAccount)!.borrow()
            ?? panic("Could not borrow a reference to the user's token manager")

        tokenManagerRef.increaseUnlockLimit(delta: delta)
    }
}
