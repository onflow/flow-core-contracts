import FlowToken from 0xFLOWTOKENADDRESS
import FungibleToken from 0xFUNGIBLETOKENADDRESS
import LockedTokens from 0xLOCKEDTOKENADDRESS

/// Transaction that the main token admin would sign
/// to create a shared account and an unlocked
/// acount for a user

transaction(
    partialAdminPublicKey: [UInt8], // Weight: 100
    partialUserPublicKey: [UInt8], // Weight: 900
    fullUserPublicKey: [UInt8], // Weight: 1000
)  {

    prepare(admin: AuthAccount) {

        // Create the new accounts and add their keys
        let sharedAccount = AuthAccount(payer: admin)
        let userAccount = AuthAccount(payer: admin)

        sharedAccount.addPublicKey(partialAdminPublicKey)
        sharedAccount.addPublicKey(partialUserPublicKey)

        userAccount.addPublicKey(fullUserPublicKey)

        // Create a private link to the stored vault
        let vaultCapability = sharedAccount
            .link<&FlowToken.Vault>(
                /private/flowTokenVault,
                target: /storage/flowTokenVault
            )
            ?? panic("Could not link Flow Token Vault capability")

        // create a locked token manager and stored it in the shared account
        let lockedTokenManager <- LockedTokens.createLockedTokenManager(vault: vaultCapability)
        sharedAccount.save(<-lockedTokenManager, to: LockedTokens.LockedTokenManagerStoragePath)

        let tokenManagerCapability = sharedAccount
            .link<&LockedTokens.LockedTokenManager>(
                LockedTokens.LockedTokenManagerPrivatePath,
                target: LockedTokens.LockedTokenManagerStoragePath
        )   ?? panic("Could not link token manager capability")

        let tokenHolder <- LockedTokens.createTokenHolder(
            lockedAddress: sharedAccount.address,
            tokenManager: tokenManagerCapability
        )

        userAccount.save(
            <-tokenHolder,
            to: LockedTokens.TokenHolderStoragePath,
        )

        userAccount.link<&LockedTokens.TokenHolder{LockedTokens.LockedAccountInfo}>(
            LockedTokens.LockedAccountInfoPublicPath,
            target: LockedTokens.TokenHolderStoragePath
        )

        let tokenAdminCapability = sharedAccount
            .link<&LockedTokens.LockedTokenManager>(
                LockedTokens.LockedTokenAdminPrivatePath,
                target: LockedTokens.LockedTokenManagerStoragePath
            )
            ?? panic("Could not link token admin to token manager")

        let tokenAdminCollection = admin
            .borrow<&LockedTokens.TokenAdminCollection>(
                from: LockedTokens.LockedTokenAdminCollectionStoragePath
            )
            ?? panic("Could not borrow reference to admin collection")

        tokenAdminCollection.addAccount(
            sharedAccountAddress: sharedAccount.address,
            unlockedAccountAddress: userAccount.address,
            tokenAdmin: tokenAdminCapability
        )

        // Override the default FlowToken receiver
        sharedAccount.unlink(/public/flowTokenReceiver)

        // create new receiver that marks received tokens as unlocked
        sharedAccount.link<&AnyResource{FungibleToken.Receiver}>(
            /public/flowTokenReceiver,
            target: LockedTokens.LockedTokenManagerStoragePath
        )

        // put normal receiver in a separate unique path
        sharedAccount.link<&AnyResource{FungibleToken.Receiver}>(
            /public/lockedFlowTokenReceiver,
            target: /storage/flowTokenVault
        )
    }
}
