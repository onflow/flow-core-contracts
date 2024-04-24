import Crypto
import FlowToken from "FlowToken"
import FungibleToken from "FungibleToken"
import LockedTokens from "LockedTokens"

/// Transaction that the main token admin would sign
/// to create a shared account and an unlocked
/// acount for a user

transaction(
    partialAdminPublicKey: Crypto.KeyListEntry, // Weight: 100
    partialUserPublicKey: Crypto.KeyListEntry, // Weight: 900
    fullUserPublicKey: Crypto.KeyListEntry, // Weight: 1000
)  {

    prepare(admin: auth(BorrowValue) &Account) {

        // Create the new accounts and add their keys
        let sharedAccount = Account(payer: admin)
        let userAccount = Account(payer: admin)

        sharedAccount.keys.add(publicKey: partialAdminPublicKey.publicKey, hashAlgorithm: partialAdminPublicKey.hashAlgorithm, weight: partialAdminPublicKey.weight)
        sharedAccount.keys.add(publicKey: partialUserPublicKey.publicKey, hashAlgorithm: partialUserPublicKey.hashAlgorithm, weight: partialUserPublicKey.weight)

        userAccount.keys.add(publicKey: fullUserPublicKey.publicKey, hashAlgorithm: fullUserPublicKey.hashAlgorithm, weight: fullUserPublicKey.weight)

        // Create a private link to the stored vault
        let vaultCapability = sharedAccount.capabilities.storage.issue
            <auth(FungibleToken.Withdraw) &FlowToken.Vault>
            (/storage/flowTokenVault)

        // create a locked token manager and stored it in the shared account
        let lockedTokenManager <- LockedTokens.createLockedTokenManager(vault: vaultCapability)
        sharedAccount.storage.save(<-lockedTokenManager, to: LockedTokens.LockedTokenManagerStoragePath)

        let tokenManagerCapability = sharedAccount
            .capabilities.storage.issue<auth(FungibleToken.Withdraw) &LockedTokens.LockedTokenManager>(
                LockedTokens.LockedTokenManagerStoragePath)

        let tokenHolder <- LockedTokens.createTokenHolder(
            lockedAddress: sharedAccount.address,
            tokenManager: tokenManagerCapability
        )

        userAccount.storage.save(
            <-tokenHolder,
            to: LockedTokens.TokenHolderStoragePath
        )

        let infoCap = userAccount.capabilities.storage.issue<&LockedTokens.TokenHolder>(
            LockedTokens.TokenHolderStoragePath
        )
        userAccount.capabilities.publish(infoCap, at: LockedTokens.LockedAccountInfoPublicPath)

        let tokenAdminCollection = admin.storage
            .borrow<auth(LockedTokens.AccountCreator) &LockedTokens.TokenAdminCollection>(
                from: LockedTokens.LockedTokenAdminCollectionStoragePath
            )
            ?? panic("Could not borrow reference to admin collection")

        tokenAdminCollection.addAccount(
            sharedAccountAddress: sharedAccount.address,
            unlockedAccountAddress: userAccount.address,
            tokenAdmin: tokenManagerCapability
        )

        // Override the default FlowToken receiver
        sharedAccount.capabilities.unpublish(/public/flowTokenReceiver)

        // create new receiver that marks received tokens as unlocked
        let lockedTokensManagerCap = sharedAccount.capabilities.storage.issue<&{FungibleToken.Receiver}>(LockedTokens.LockedTokenManagerStoragePath)
        sharedAccount.capabilities.publish(
            lockedTokensManagerCap,
            at: /public/flowTokenReceiver
        )

        // put normal receiver in a separate unique path
        let tokenReceiverCap = sharedAccount.capabilities.storage.issue<&{FungibleToken.Receiver}>(/storage/flowTokenVault)
        sharedAccount.capabilities.publish(
            tokenReceiverCap,
            at: /public/lockedFlowTokenReceiver
        )
    }
}
