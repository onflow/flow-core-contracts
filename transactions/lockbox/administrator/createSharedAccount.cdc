import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from 0xee82856bf20e2aa6
import Lockbox from 0

// createSharedAccount
transaction(adminPublicKey: [UInt8], userPublicKey: [UInt8])  {
    prepare(admin: AuthAccount) {
        let sharedAccount = AuthAccount(payer: admin)
        let userAccount = AuthAccount(payer: admin)

        sharedAccount.addPublicKey(adminPublicKey)
        sharedAccount.addPublicKey(userPublicKey)

        // TODO: add separate full-weight key for user
        userAccount.addPublicKey(userPublicKey)

        let vaultCapability = sharedAccount
            .getCapability<&FlowToken.Vault>(/storage/flowTokenVault)!

        let lockedTokenManager <- Lockbox.createNewLockedTokenManager(vault: vaultCapability)

        sharedAccount.save(<-lockedTokenManager, to: Lockbox.LockedTokenManagerPath)

        let tokenManagerCapability = sharedAccount
            .link<&Lockbox.LockedTokenManager>(
                Lockbox.LockedTokenStakingProxyPrivatePath,
                target: Lockbox.LockedTokenManagerPath
        )

        tokenManagerRef = tokenManagerCapability.borrow()!

        let tokenHolder <- tokenManagerRef.createTokenHolder(tokenManager: tokenManagerCapability)

        userAccount.save(
            tokenHolder, 
            to: Lockbox.TokenHolderStoragePath,
        )

        let tokenAdminCapability = sharedAccount
            .link<&Lockbox.LockedTokenManager{Lockbox.TokenAdmin}>(
                Lockbox.LockedTokenAdminPrivatePath,
                target: Lockbox.LockedTokenManagerPath
        )

        let tokenAdminCollection = admin
            .borrow<&Lockbox.TokenAdminCollection>(from: Lockbox.LockedTokenAdminCollectionPath)

        tokenAdminCollection.addAccount(sharedAccount.address, tokenAdminCapability)

        // Override the default FlowToken receiver
        sharedAccount.unlink(/public/flowTokenReceiver)
            
        sharedAccount.link<&AnyResource{FungibleToken.Receiver}>(
            /public/flowTokenReceiver,
            target: Lockbox.LockedTokenManagerPath
        )

        sharedAccount.link<&AnyResource{FungibleToken.Receiver}>(
            /public/lockedFlowTokenReceiver,
            target: /storage/flowTokenVault
        )
    }
}
