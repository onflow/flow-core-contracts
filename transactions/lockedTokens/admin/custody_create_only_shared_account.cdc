import Crypto
import FlowToken from "FlowToken"
import FungibleToken from "FungibleToken"
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

    prepare(custodyProvider: auth(BorrowValue) &Account, userAccount: auth(Storage, Capabilities) &Account) {

        let sharedAccount = Account(payer: custodyProvider)

        sharedAccount.keys.add(publicKey: partialAdminPublicKey.publicKey, hashAlgorithm: partialAdminPublicKey.hashAlgorithm, weight: partialAdminPublicKey.weight)
        sharedAccount.keys.add(publicKey: partialUserPublicKey.publicKey, hashAlgorithm: partialUserPublicKey.hashAlgorithm, weight: partialUserPublicKey.weight)

        let vaultCapability = sharedAccount.capabilities.storage
            .issue<auth(FungibleToken.Withdrawable) &FlowToken.Vault>(/storage/flowTokenVault)

        let lockedTokenManager <- LockedTokens.createLockedTokenManager(vault: vaultCapability)

        sharedAccount.storage.save(<-lockedTokenManager, to: LockedTokens.LockedTokenManagerStoragePath)

        let tokenManagerCapability = sharedAccount.capabilities.storage
            .issue<auth(FungibleToken.Withdrawable) &LockedTokens.LockedTokenManager>(
                LockedTokens.LockedTokenManagerStoragePath
            )

        let tokenHolder <- LockedTokens.createTokenHolder(
            lockedAddress: sharedAccount.address,
            tokenManager: tokenManagerCapability
        )

        userAccount.storage.save(
            <-tokenHolder,
            to: LockedTokens.TokenHolderStoragePath,
        )

        let tokenHolderCap = userAccount.capabilities.storage.issue<&LockedTokens.TokenHolder>(LockedTokens.TokenHolderStoragePath)
        userAccount.capabilities.publish(tokenHolderCap, at: LockedTokens.LockedAccountInfoPublicPath)

        let tokenAdminCapability = sharedAccount.capabilities.storage
            .issue<auth(FungibleToken.Withdrawable) &LockedTokens.LockedTokenManager>(
                LockedTokens.LockedTokenManagerStoragePath
            )

        let lockedAccountCreator = custodyProvider.storage
            .borrow<&LockedTokens.LockedAccountCreator>(from: LockedTokens.LockedAccountCreatorStoragePath)

        lockedAccountCreator.addAccount(
            sharedAccountAddress: sharedAccount.address,
            unlockedAccountAddress: userAccount.address,
            tokenAdmin: tokenAdminCapability
        )

        // Override the default FlowToken receiver.
        sharedAccount.capabilities.unpublish(/public/flowTokenReceiver)

        // create new receiver that marks received tokens as unlocked.
        let lockedTokensManagerCap = sharedAccount.capabilties.storage.issue<&{FungibleToken.Receiver}>(LockedTokens.LockedTokenManagerStoragePath)
        sharedAccount.capabilties.publish(
            lockedTokensManagerCap,
            at: /public/flowTokenReceiver
        )

        // put normal receiver in a separate unique path.
        let tokenReceiverCap = sharedAccount.capabilties.storage.issue<&{FungibleToken.Receiver}>(/storage/flowTokenVault)
        sharedAccount.capabilties.publish(
            tokenReceiverCap,
            at: /public/lockedFlowTokenReceiver
        )
    }
}
