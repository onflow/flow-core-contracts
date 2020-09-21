import FungibleToken from 0xee82856bf20e2aa6
import FlowStakingHelper from 0x045a1763c93006ca

transaction(amount: UFix64) {
    let helper: &FlowStakingHelper.StakingHelper

    prepare(signer: AuthAccount) {
                // Get a reference to the signer's stored vault
        let vaultRef = signer.borrow<&FungibleToken.Vault>(from: /storage/flowTokenVault)
			?? panic("Could not borrow reference to the owner's Vault!")

        // Withdraw tokens from the signer's stored vault
        self.helper = signer.getCapability(/public/linkStakingHelper)!
            .borrow<&Capability>()!
            .borrow<&FlowStakingHelper.StakingHelper>()!
    }

    execute{
        self.helper.withdrawEscrow(amount: amount)
    }
}
