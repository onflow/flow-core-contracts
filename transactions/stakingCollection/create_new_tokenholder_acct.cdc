import FlowToken from 0xFLOWTOKENADDRESS
import LockedTokens from 0xLOCKEDTOKENADDRESS
import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

// This transaction allows the controller of the locked account
// to create a new LockedTokens.TokenHolder object and store it in a new account
// also adding a staking collection object to the new account

// Keep in mind that this does not invalidate the existing TokenHolder account
// To invalidate that account, you need to either delete the TokenHolder resource
// or revoke all keys from that account

transaction(publicKeys: [String]) {
    prepare(signer: AuthAccount) {

        // Create the new account and add public keys
        let newAccount = AuthAccount(payer: signer)
        for key in publicKeys {
            newAccount.addPublicKey(key.decodeHex())
        }

        // Get the TokenManager Capability from the locked account
        let tokenManagerCapability = signer
            .getCapability<&LockedTokens.LockedTokenManager>(
            LockedTokens.LockedTokenManagerPrivatePath)

        // Use the manager capability to create a new TokenHolder
        let tokenHolder <- LockedTokens.createTokenHolder(
            lockedAddress: signer.address,
            tokenManager: tokenManagerCapability
        )

        // Save the TokenHolder resource to the new account and create a public capability
        newAccount.save(
            <-tokenHolder,
            to: LockedTokens.TokenHolderStoragePath,
        )

        newAccount.link<&LockedTokens.TokenHolder{LockedTokens.LockedAccountInfo}>(
            LockedTokens.LockedAccountInfoPublicPath,
            target: LockedTokens.TokenHolderStoragePath
        )


        // Create private capabilities for the token holder and unlocked vault
        let lockedHolder = newAccount.link<&LockedTokens.TokenHolder>(/private/flowTokenHolder, target: LockedTokens.TokenHolderStoragePath)!
        let flowToken = newAccount.link<&FlowToken.Vault>(/private/flowTokenVault, target: /storage/flowTokenVault)!
        
        // Create a new Staking Collection and put it in storage
        if lockedHolder.check() {
            newAccount.save(<-FlowStakingCollection.createStakingCollection(unlockedVault: flowToken, tokenHolder: lockedHolder), to: FlowStakingCollection.StakingCollectionStoragePath)
        } else {
            newAccount.save(<-FlowStakingCollection.createStakingCollection(unlockedVault: flowToken, tokenHolder: nil), to: FlowStakingCollection.StakingCollectionStoragePath)
        }

        // Create a public link to the staking collection
        newAccount.link<&FlowStakingCollection.StakingCollection{FlowStakingCollection.StakingCollectionPublic}>(
            FlowStakingCollection.StakingCollectionPublicPath,
            target: FlowStakingCollection.StakingCollectionStoragePath
        )
    }
}