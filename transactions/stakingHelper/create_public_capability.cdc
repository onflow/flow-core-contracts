import FlowStakingHelper from 0x045a1763c93006ca

transaction {
    let account: AuthAccount
    let capabilityPath: Path
    let storagePath: Path

    prepare(account: AuthAccount){
        self.account = account
        self.capabilityPath = /public/linkStakingHelper
        self.storagePath = FlowStakingHelper.HelperStoragePath
    }

    execute {
        self.account.link<&Capability>(self.capabilityPath, target: self.storagePath)
        let ref = self.account
            .getCapability(self.capabilityPath)!
            .borrow<&Capability>()!
            .borrow<&FlowStakingHelper.StakingHelper>()!
        log("CUT: ".concat(ref.cutPercentage.toString()))
    }

    post {
        /* 
        self.account
            .getCapability(self.capabilityPath)!
            .check<&Capability>() : "Capability link wasn't created"
        */
    }
}