import Lockbox from 0xf3fcd2c1a78f5eee
import StakingProxy from 0x179b6b1cb6755e31

transaction(amount: UFix64) {

    let holderRef: &Lockbox.TokenHolder

    prepare(acct: AuthAccount) {
        self.holderRef = acct.borrow<&Lockbox.TokenHolder>(from: Lockbox.TokenHolderStoragePath)
            ?? panic("Could not borrow reference to TokenHolder")
    }

    execute {
        let stakerProxy = self.holderRef.borrowStaker()

        stakerProxy.stakeRewardedTokens(amount: amount)
    }

}
