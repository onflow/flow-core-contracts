import LockedTokens from 0xLOCKEDTOKENADDRESS

// This transaction uses the locked tokens admin
// to set the unlock limit for multiple accounts
// in a single transaction
<<<<<<< HEAD
// The account addresses should be the unlocked account addresses

=======
// The addresses used as keys are the unlocked
// addresses for the accounts
>>>>>>> origin/kan/multi-unlock
transaction(unlockInfo: {Address: UFix64}) {

    prepare(admin: AuthAccount) {

        let adminRef = admin.borrow<&LockedTokens.TokenAdminCollection>(from: LockedTokens.LockedTokenAdminCollectionStoragePath)
            ?? panic("Could not borrow a reference to the admin collection")

        for unlockedAddress in unlockInfo.keys {

            // All of the if lets are because we don't  want to
            // revert the entire transaction if it fails
            // to get the information for a single address
            if let lockedAccountInfoRef = getAccount(unlockedAddress)
                .getCapability<&LockedTokens.TokenHolder{LockedTokens.LockedAccountInfo}>(LockedTokens.LockedAccountInfoPublicPath)
                .borrow() {

                let lockedAccountAddress = lockedAccountInfoRef.getLockedAccountAddress()

                if let lockedTokenAccountRecord = adminRef.getAccount(address: lockedAccountAddress) {
                    
                    if let tokenManagerRef = lockedTokenAccountRecord.borrow() {

                        let unlockLimit = lockedAccountInfoRef.getUnlockLimit()

                        // Some accounts may already have some unlocked tokens
                        // from tokens delivered after storage minimums were enabled
                        // So those should be subtracted from the unlock amount
                        var unlockAmount = unlockInfo[unlockedAddress]!
                        unlockAmount = unlockAmount - unlockLimit

                        tokenManagerRef.increaseUnlockLimit(delta: unlockAmount)
                    }
                }
            }
        }
    }
}
