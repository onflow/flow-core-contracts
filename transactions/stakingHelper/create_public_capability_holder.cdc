import FlowStakingHelper from 0x045a1763c93006ca

transaction {
    let account: AuthAccount
    let storagePath: Path
    let capabilityPath: Path

    prepare(account: AuthAccount){
        self.account = account
        self.capabilityPath = /public/flowStakingHelper
        self.storagePath = FlowStakingHelper.HelperStoragePath
    }

    execute{
        self.account.link<&FlowStakingHelper.StakingHelper>(self.capabilityPath, target: self.storagePath)
        
        log("Public capability for holder account was created!")
        let ref = self.account
            .getCapability(self.capabilityPath)!
            .borrow<&FlowStakingHelper.StakingHelper>()!
        
        log("CUT: ".concat(ref.cutPercentage.toString()))
    }

    post{
        self.account
            .getCapability(self.capabilityPath)!
            .check<&FlowStakingHelper.StakingHelper>() : "Capability link wasn't created"
    }
}
