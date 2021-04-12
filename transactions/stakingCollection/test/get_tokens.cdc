import FlowStakingCollection from 0xSTAKINGCOLLECTIONADDRESS
import FlowToken from 0xFLOWTOKENADDRESS
import FungibleToken from 0xFUNGIBLETOKENADDRESS
import LockedTokens from 0xLOCKEDTOKENADDRESS

// Used only for test purposes to test the get tokens function in the staking collection

transaction(amount: UFix64) {

    prepare(signer: AuthAccount) {

        let collectionRef = signer.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic("Could not borrow a reference to the staking collection")
            
        let tokens <- collectionRef.getTokens(amount: amount)

        destroy tokens
    }
}
 