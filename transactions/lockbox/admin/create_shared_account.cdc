import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from 0xee82856bf20e2aa6
import Lockbox from 0xf3fcd2c1a78f5eee

// createSharedAccount
transaction(
    partialAdminPublicKey: [UInt8], // Weight: 100
    partialUserPublicKey: [UInt8], // Weight: 900
    fullUserPublicKey: [UInt8], // Weight: 1000
)  {
    prepare(admin: AuthAccount) {
        let sharedAccount = AuthAccount(payer: admin)
        let userAccount = AuthAccount(payer: admin)

        sharedAccount.addPublicKey(partialAdminPublicKey)
        sharedAccount.addPublicKey(partialUserPublicKey)

        userAccount.addPublicKey(fullUserPublicKey)

        let vaultCapability = sharedAccount
            .link<&FlowToken.Vault>(/private/flowTokenVault, target: /storage/flowTokenVault)
            ?? panic("Could not link Flow Token Vault capability")

        let lockedTokenManager <- Lockbox.createNewLockedTokenManager(vault: vaultCapability)

        sharedAccount.save(<-lockedTokenManager, to: Lockbox.LockedTokenManagerStoragePath)

        let tokenManagerCapability = sharedAccount
            .link<&Lockbox.LockedTokenManager>(
                Lockbox.LockedTokenManagerPrivatePath,
                target: Lockbox.LockedTokenManagerStoragePath
        )   ?? panic("Could not link token manager capability")

        let tokenHolder <- Lockbox.createTokenHolder(tokenManager: tokenManagerCapability)

        userAccount.save(
            <-tokenHolder, 
            to: Lockbox.TokenHolderStoragePath,
        )

        let tokenAdminCapability = sharedAccount
            .link<&Lockbox.LockedTokenManager{Lockbox.TokenAdmin}>(
                Lockbox.LockedTokenAdminPrivatePath,
                target: Lockbox.LockedTokenManagerStoragePath)
            ?? panic("Could not link token admin to token manager")

        let tokenAdminCollection = admin
            .borrow<&Lockbox.TokenAdminCollection>(from: Lockbox.LockedTokenAdminCollectionStoragePath)
            ?? panic("Could not borrow reference to admin collection")

        tokenAdminCollection.addAccount(address: sharedAccount.address, tokenAdmin: tokenAdminCapability)

        // Override the default FlowToken receiver
        sharedAccount.unlink(/public/flowTokenReceiver)
            
        // create new receiver that marks received tokens as unlocked
        sharedAccount.link<&AnyResource{FungibleToken.Receiver}>(
            /public/flowTokenReceiver,
            target: Lockbox.LockedTokenManagerStoragePath
        )

        // pub normal receiver in a separate unique path
        sharedAccount.link<&AnyResource{FungibleToken.Receiver}>(
            /public/lockedFlowTokenReceiver,
            target: /storage/flowTokenVault
        )
    }
}
