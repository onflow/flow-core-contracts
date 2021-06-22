import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS
import FlowToken from 0xFLOWTOKENADDRESS
import FungibleToken from 0xFUNGIBLETOKENADDRESS
import LockedTokens from 0xLOCKEDTOKENADDRESS

// Used only for test purposes to test the deposit token function in the staking collection

transaction(amount: UFix64) {

    prepare(signer: AuthAccount) {

        let collectionRef = signer.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic("Could not borrow a reference to the staking collection")

        let flowTokenRef = signer.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to FLOW Vault")

        let tokens <- collectionRef.getTokens(amount: amount)
            
        collectionRef.depositTokens(from: <-tokens)
    }
}