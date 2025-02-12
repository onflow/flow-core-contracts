import "FlowStakingCollection"
import "FlowToken"
import "FungibleToken"
import "LockedTokens"

// Used only for test purposes to test the deposit token function in the staking collection

transaction(amount: UFix64) {

    prepare(signer: auth(BorrowValue) &Account) {

        let collectionRef = signer.storage.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic("Could not borrow a reference to the staking collection")

        let flowTokenRef = signer.storage.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to FLOW Vault")

        let tokens <- collectionRef.getTokens(amount: amount)
            
        collectionRef.depositTokens(from: <-tokens)
    }
}