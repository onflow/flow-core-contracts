import Crypto
import FlowToken from "FlowToken"
import FungibleToken from "FungibleToken"
import LockedTokens from 0xLOCKEDTOKENADDRESS
import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

// This transaction allows the controller of the locked account
// to create a new LockedTokens.TokenHolder object and store it in a new account
// also adding a staking collection object to the new account

// Keep in mind that this does not invalidate the existing TokenHolder account
// To invalidate that account, you need to either delete the TokenHolder resource
// or revoke all keys from that account

transaction(publicKeys: [Crypto.KeyListEntry]) {
    prepare(signer: auth(BorrowValue, Storage, Capabilities) &Account) {

        // Create the new account and add public keys.
        let newAccount = Account(payer: signer)
        for key in publicKeys {
            newAccount.keys.add(publicKey: key.publicKey, hashAlgorithm: key.hashAlgorithm, weight: key.weight)
        }

        // Get the TokenManager Capability from the locked account.
        let tokenManagerCapabilityController = signer.capabilities.storage.getControllers(forPath: LockedTokens.LockedTokenManagerStoragePath)[1]!
        let tokenManagerCapability = tokenManagerCapabilityController.capability as! Capability<auth(FungibleToken.Withdraw) &LockedTokens.LockedTokenManager>

        // Use the manager capability to create a new TokenHolder.
        let tokenHolder <- LockedTokens.createTokenHolder(
            lockedAddress: signer.address,
            tokenManager: tokenManagerCapability
        )

        // Save the TokenHolder resource to the new account and create a public capability.
        newAccount.storage.save(
            <-tokenHolder,
            to: LockedTokens.TokenHolderStoragePath
        )

        let tokenHolderCap = newAccount.capabilities.storage
            .issue<&LockedTokens.TokenHolder>(LockedTokens.TokenHolderStoragePath)
        newAccount.capabilities.publish(
            tokenHolderCap,
            at: LockedTokens.LockedAccountInfoPublicPath
        )


        // Create capabilities for the token holder and unlocked vault.
        let lockedHolder = newAccount.capabilities.storage.issue<auth(FungibleToken.Withdraw, LockedTokens.TokenOperations) &LockedTokens.TokenHolder>(LockedTokens.TokenHolderStoragePath)
        let flowToken = newAccount.capabilities.storage.issue<auth(FungibleToken.Withdraw) &FlowToken.Vault>(/storage/flowTokenVault)
        
        // Create a new Staking Collection and put it in storage.
        if lockedHolder.check() {
            newAccount.storage.save(
                <- FlowStakingCollection.createStakingCollection(
                    unlockedVault: flowToken,
                    tokenHolder: lockedHolder
                ),
                to: FlowStakingCollection.StakingCollectionStoragePath
            )
        } else {
            newAccount.storage.save(
                <- FlowStakingCollection.createStakingCollection(
                    unlockedVault: flowToken,
                    tokenHolder: nil
                ),
                to: FlowStakingCollection.StakingCollectionStoragePath
            )
        }

        // Publish a capability to the created staking collection.
        let stakingCollectionCap = newAccount.capabilities.storage.issue<&FlowStakingCollection.StakingCollection>(
            FlowStakingCollection.StakingCollectionStoragePath
        )

        newAccount.capabilities.publish(
            stakingCollectionCap,
            at: FlowStakingCollection.StakingCollectionPublicPath
        )
    }
}