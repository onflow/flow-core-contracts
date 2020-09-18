import FlowStakingHelper from 0x045a1763c93006ca

transaction {
    let account: AuthAccount
    let storagePath: Path

    prepare(account: AuthAccount){
        self.account = account
        self.storagePath = FlowStakingHelper.HelperStoragePath
    }

    execute{
        let copy = self.account.copy<Capability>(from: self.storagePath)
        let ref = copy!.borrow<&FlowStakingHelper.StakingHelper>()!
    
        log("Cut percentage:".concat(ref.cutPercentage.toString()))
    }
}