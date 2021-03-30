import FungibleToken from 0xFUNGIBLETOKENADDRESS
import FlowToken from 0xFLOWTOKENADDRESS
import LockedTokens from 0xLOCKEDTOKENADDRESS
import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS

transaction() {
    prepare(signer: AuthAccount) {

        if signer.borrow<&FlowStakingCollection.StakingCollection{FlowStakingCollection.StakingCollectionPublic}>(from: FlowStakingCollection.StakingCollectionStoragePath) == nil {

            let lockedHolder = signer.link<&LockedTokens.TokenHolder>(/private/flowTokenHolder, target: LockedTokens.TokenHolderStoragePath)!
            let flowToken = signer.link<&FlowToken.Vault>(/private/flowTokenVault, target: /storage/flowTokenVault)!
            
            // Create a new Staking Collection and put it in storage
            if lockedHolder.check() {
                signer.save(<-FlowStakingCollection.createStakingCollection(vaultCapability: flowToken, tokenHolder: lockedHolder), to: FlowStakingCollection.StakingCollectionStoragePath)
            } else {
                signer.save(<-FlowStakingCollection.createStakingCollection(vaultCapability: flowToken, tokenHolder: nil), to: FlowStakingCollection.StakingCollectionStoragePath)
            }

            signer.link<&FlowStakingCollection.StakingCollection{FlowStakingCollection.StakingCollectionPublic}>(
                FlowStakingCollection.StakingCollectionPublicPath,
                target: FlowStakingCollection.StakingCollectionStoragePath
            )
        }
    }
}
