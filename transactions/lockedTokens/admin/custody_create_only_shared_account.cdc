import FlowToken from 0x0ae53cb6e3f42a79
import FungibleToken from 0xee82856bf20e2aa6
import LockedTokens from 0xf3fcd2c1a78f5eee

/// Transaction that a custody provider would sign
/// to create a shared account for a user who already
/// has their unlocked account created
///
/// The unlocked account has to sign the transaction also

transaction(
    partialAdminPublicKey: [UInt8], // Weight: 100
    partialUserPublicKey: [UInt8], // Weight: 900
)  {

    prepare(custodyProvider: AuthAccount, userAccount: AuthAccount) {

        let sharedAccount = AuthAccount(payer: custodyProvider)

        sharedAccount.addPublicKey(partialAdminPublicKey)
        sharedAccount.addPublicKey(partialUserPublicKey)

        let vaultCapability = sharedAccount
            .link<&FlowToken.Vault>(/private/flowTokenVault, target: /storage/flowTokenVault)
            ?? panic("Could not link Flow Token Vault capability")

        let lockedTokenManager <- LockedTokens.createLockedTokenManager(vault: vaultCapability)

        sharedAccount.save(<-lockedTokenManager, to: LockedTokens.LockedTokenManagerStoragePath)

        let tokenManagerCapability = sharedAccount
            .link<&LockedTokens.LockedTokenManager>(
                LockedTokens.LockedTokenManagerPrivatePath,
                target: LockedTokens.LockedTokenManagerStoragePath
        )   ?? panic("Could not link token manager capability")

        let tokenHolder <- LockedTokens.createTokenHolder(tokenManager: tokenManagerCapability)

        userAccount.save(
            <-tokenHolder, 
            to: LockedTokens.TokenHolderStoragePath,
        )

        userAccount.link<&LockedTokens.TokenHolder{LockedTokens.LockedAccountInfo}>(LockedTokens.UnlockLimitPublicPath, target: LockedTokens.TokenHolderStoragePath)

        let tokenAdminCapability = sharedAccount
            .link<&LockedTokens.LockedTokenManager>(
                LockedTokens.LockedTokenAdminPrivatePath,
                target: LockedTokens.LockedTokenManagerStoragePath)
            ?? panic("Could not link token custodyProvider to token manager")


        let lockedAccountCreator = custodyProvider
            .borrow<&LockedTokens.LockedAccountCreator>(from: LockedTokens.LockedAccountCreatorStoragePath)
            ?? panic("Could not borrow reference to LockedAccountCreator")

        lockedAccountCreator.addAccount(sharedAccountAddress: sharedAccount.address, unlockedAccountAddress: userAccount.address, tokenAdmin: tokenAdminCapability)

        // Override the default FlowToken receiver
        sharedAccount.unlink(/public/flowTokenReceiver)
            
        // create new receiver that marks received tokens as unlocked
        sharedAccount.link<&AnyResource{FungibleToken.Receiver}>(
            /public/flowTokenReceiver,
            target: LockedTokens.LockedTokenManagerStoragePath
        )

        // pub normal receiver in a separate unique path
        sharedAccount.link<&AnyResource{FungibleToken.Receiver}>(
            /public/lockedFlowTokenReceiver,
            target: /storage/flowTokenVault
        )
    }
}
