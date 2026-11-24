import "FlowStakingCollection"
import "FungibleToken"

/// Withdraw rewarded tokens from the specified node or delegator in the staking
/// collection and RETURN them as a vault to the caller, instead of depositing
/// them into the collection's own vault.
///
/// This transaction deposits the returned vault into the caller's own vault to
/// show it is a usable vault; a caller that needs to route the funds elsewhere
/// (e.g. bridging them to an EVM account) can deposit it wherever it likes.
///
/// Only works for collections without a locked account — see
/// `withdrawRewardedTokensAsVault`.
transaction(nodeID: String, delegatorID: UInt32?, amount: UFix64) {

    let stakingCollectionRef: auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection
    let receiver: &{FungibleToken.Receiver}

    prepare(account: auth(BorrowValue) &Account) {
        self.stakingCollectionRef = account.storage.borrow<auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic(FlowStakingCollection.getCollectionMissingError(nil))

        self.receiver = account.storage.borrow<&{FungibleToken.Receiver}>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow a receiver reference to the FlowToken Vault")
    }

    execute {
        let tokens <- self.stakingCollectionRef.withdrawRewardedTokensAsVault(nodeID: nodeID, delegatorID: delegatorID, amount: amount)
        self.receiver.deposit(from: <-tokens)
    }
}
