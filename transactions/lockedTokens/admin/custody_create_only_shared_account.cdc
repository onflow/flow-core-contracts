import Crypto
import FlowToken from 0xFLOWTOKENADDRESS
import FungibleToken from 0xFUNGIBLETOKENADDRESS
import LockedTokens from 0xLOCKEDTOKENADDRESS

/// Transaction that a custody provider would sign
/// to create a shared account for a user who already
/// has their unlocked account created
///
/// The unlocked account has to sign the transaction also

transaction(
    partialAdminPublicKey: Crypto.KeyListEntry, // Weight: 100
    partialUserPublicKey: Crypto.KeyListEntry, // Weight: 900
)  {

    prepare(custodyProvider: AuthAccount, userAccount: AuthAccount) {

        let sharedAccount = AuthAccount(payer: custodyProvider)

        sharedAccount.keys.add(publicKey: partialAdminPublicKey.publicKey, hashAlgorithm: partialAdminPublicKey.hashAlgorithm, weight: partialAdminPublicKey.weight)
        sharedAccount.keys.add(publicKey: partialUserPublicKey.publicKey, hashAlgorithm: partialUserPublicKey.hashAlgorithm, weight: partialUserPublicKey.weight)

        let vaultCapability = sharedAccount
            .link<&FlowToken.Vault>(/private/flowTokenVault, target: /storage/flowTokenVault)
            ?? panic("Could not link Flow Token Vault capability")

        let lockedTokenManager <- LockedTokens.createLockedTokenManager(vault: vaultCapability)

        sharedAccount.save(<-lockedTokenManager, to: LockedTokens.LockedTokenManagerStoragePath)

        let tokenManagerCapability = sharedAccount
            .link<&LockedTokens.LockedTokenManager>(
                LockedTokens.LockedTokenManagerPrivatePath,
                target: LockedTokens.LockedTokenManagerStoragePath
            )
            ?? panic("Could not link token manager capability")

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
            ?? panic("Could not link token custodyProvider to token manager")


        let lockedAccountCreator = custodyProvider
            .borrow<&LockedTokens.LockedAccountCreator>(
                from: LockedTokens.LockedAccountCreatorStoragePath
            )
            ?? panic("Could not borrow reference to LockedAccountCreator")

        lockedAccountCreator.addAccount(
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

        // pub normal receiver in a separate unique path
        sharedAccount.link<&AnyResource{FungibleToken.Receiver}>(
            /public/lockedFlowTokenReceiver,
            target: /storage/flowTokenVault
        )
    }
}
