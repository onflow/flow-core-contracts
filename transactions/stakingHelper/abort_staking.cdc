import FungibleToken from 0xee82856bf20e2aa6
import FlowStakingHelper from 0x045a1763c93006ca

transaction() {
    let helper: &FlowStakingHelper.StakingHelper

    prepare(signer: AuthAccount) {
        self.helper = signer.getCapability(/public/linkStakingHelper)!
            .borrow<&Capability>()!
            .borrow<&FlowStakingHelper.StakingHelper>()!
    }

    execute{
        self.helper.abort()
    }
}
