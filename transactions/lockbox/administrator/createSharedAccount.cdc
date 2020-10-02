import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from 0xee82856bf20e2aa6
import Lockbox from 0

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
            .getCapability<&FlowToken.Vault>(/storage/flowTokenVault)!

        let lockedTokenManager <- Lockbox.createNewLockedTokenManager(vault: vaultCapability)

        sharedAccount.save(<-lockedTokenManager, to: Lockbox.LockedTokenManagerPath)

        let tokenManagerCapability = sharedAccount
            .link<&Lockbox.LockedTokenManager>(
                Lockbox.LockedTokenStakingProxyPrivatePath,
                target: Lockbox.LockedTokenManagerPath
        )

        let tokenHolder <- Lockbox.createTokenHolder(tokenManager: tokenManagerCapability)

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
