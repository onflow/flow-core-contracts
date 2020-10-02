// import Lockbox from 0
// import StakingProxy from 0

transaction(amount: UFix64) {

    let holderRef: &LockBox.TokenHolder

    prepare(acct: AuthAccount) {
        self.holderRef = acct.borrow<&LockBox.TokenHolder>(from: LockBox.TokenHolderStoragePath)
    }

    execute {

        let stakerProxy = self.holderRef.borrowStaker()

        stakerProxy.stakeNewTokens(amount: amount)
    }
}