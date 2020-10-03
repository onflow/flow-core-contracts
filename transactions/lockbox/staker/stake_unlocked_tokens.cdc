import Lockbox from 0xf3fcd2c1a78f5eee
import StakingProxy from 0x179b6b1cb6755e31

transaction(amount: UFix64) {

    let holderRef: &LockBox.TokenHolder

    prepare(acct: AuthAccount) {
        self.holderRef = acct.borrow<&LockBox.TokenHolder>(from: LockBox.TokenHolderStoragePath)
            ?? panic("Could not borrow reference to TokenHolder")
    }

    execute {
        let stakerProxy = self.holderRef.borrowStaker()

        stakerProxy.stakeUnlockedTokens(amount: amount)
    }

}
