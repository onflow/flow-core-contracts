import LockedTokens from 0xLOCKEDTOKENADDRESS

// This transaction uses the locked tokens admin
// to set the unlock limit for multiple accounts
// in a single transaction
// The account addresses used as keys
// should be the unlocked account addresses

transaction(unlockInfo: {Address: UFix64}) {

    prepare(admin: AuthAccount) {

        // Unlocked Account addresses that had some sort of error
        // are stored in this dictionary so they can be inspected later
        // If the transaction needs to run multiple times,
        // then the dictionary is not overwritten
        var badAccounts: {Address: UFix64} = admin.load<{Address: UFix64}>(from: /storage/unlockingBadAccounts)
            ?? {} as {Address: UFix64}

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

                        // Get the unlock amount from the transaction argument dictionary
                        var unlockAmount = unlockInfo[unlockedAddress]!

                        // Increase the unlock limit by the amount
                        tokenManagerRef.increaseUnlockLimit(delta: unlockAmount)

                        // Continue to the next iteration of the loop
                        // because the account succeeded and does not need
                        // to be marked as bad
                        continue
                    }
                } 
            }

            // If the execution makes it here (does not reach the continue above)
            // it means something went wrong with the unlocking for the account
            // and it needs to be saved
            badAccounts[unlockedAddress] = unlockInfo[unlockedAddress]
        }

        admin.save<{Address: UFix64}>(badAccounts, to: /storage/unlockingBadAccounts)
        admin.link<&{Address: UFix64}>(/public/unlockingBadAccounts, target: /storage/unlockingBadAccounts)
    }
}
