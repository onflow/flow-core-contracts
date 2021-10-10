import LockedTokens from 0xLOCKEDTOKENADDRESS

transaction(targetAccounts: [Address], deltas: [UFix64]) {

    prepare(admin: AuthAccount) {

        let adminRef = admin.borrow<&LockedTokens.TokenAdminCollection>(from: LockedTokens.LockedTokenAdminCollectionStoragePath)
            ?? panic("Could not borrow a reference to the admin collection")

        var i = 0

        for targetAccount in targetAccounts {

            let tokenManagerRef = adminRef.getAccount(address: targetAccount)!.borrow()
                ?? panic("Could not borrow a reference to the user's token manager")

            tokenManagerRef.increaseUnlockLimit(delta: deltas[i])

            i = i + 1
        }
    }
}
