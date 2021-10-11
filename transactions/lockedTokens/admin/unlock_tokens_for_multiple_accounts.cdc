import LockedTokens from 0xLOCKEDTOKENADDRESS

// This transaction uses the locked tokens admin
// to set the unlock limit for multiple accounts
// in a single transaction
// The addresses used as keys are the unlocked
// addresses for the accounts
transaction(unlockInfo: {Address: UFix64}) {

    prepare(admin: AuthAccount) {

        let adminRef = admin.borrow<&LockedTokens.TokenAdminCollection>(from: LockedTokens.LockedTokenAdminCollectionStoragePath)
            ?? panic("Could not borrow a reference to the admin collection")

        var i = 0

        for targetUnlockedAddress in unlockInfo.keys {

            let lockedAccountInfoRef = getAccount(unlockedAddress)
                .getCapability<&LockedTokens.TokenHolder{LockedTokens.LockedAccountInfo}>(LockedTokens.LockedAccountInfoPublicPath)!
                .borrow() ?? panic("Could not borrow a reference to public LockedAccountInfo")

            let lockedAccountAddress = lockedAccountInfoRef.getLockedAccountAddress()

            if let tokenManagerRef = adminRef.getAccount(address: lockedAccountAddress)!.borrow() {

                // Some accounts may already have some unlocked tokens
                // from tokens delivered after storage minimums were enabled
                // So those should be subtracted from the unlock amount
                var unlockAmount = unlockInfo[targetUnlockedAddress]!
                unlockAmount = unlockAmount - lockedAccountInfoRef.getUnlockLimit()

                tokenManagerRef.increaseUnlockLimit(delta: unlockAmount)
            }

            i = i + 1
        }
    }
}
