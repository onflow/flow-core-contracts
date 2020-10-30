import LockedTokens from 0xLOCKEDTOKENADDRESS
import StakingProxy from 0xSTAKINGPROXYADDRESS

transaction() {

    let holderRef: &LockedTokens.TokenHolder

    prepare(account: AuthAccount) {
        self.holderRef = account.borrow<&LockedTokens.TokenHolder>(from: LockedTokens.TokenHolderStoragePath)
            ?? panic("Could not borrow reference to TokenHolder")
    }

    execute {
        let stakerProxy = self.holderRef.borrowStaker()

        stakerProxy.unstakeAll()
    }
}
