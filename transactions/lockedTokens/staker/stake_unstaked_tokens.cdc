import LockedTokens from "LockedTokens"
import StakingProxy from "StakingProxy"
import FungibleToken from "FungibleToken"

transaction(amount: UFix64) {

    let holderRef: auth(LockedTokens.TokenOperations, FungibleToken.Withdraw) &LockedTokens.TokenHolder

    prepare(account: auth(BorrowValue) &Account) {
        self.holderRef = account.storage.borrow<auth(LockedTokens.TokenOperations, FungibleToken.Withdraw) &LockedTokens.TokenHolder>(from: LockedTokens.TokenHolderStoragePath)
            ?? panic("Could not borrow reference to TokenHolder")
    }

    execute {
        let stakerProxy = self.holderRef.borrowStaker()

        stakerProxy.stakeUnstakedTokens(amount: amount)
    }
}
