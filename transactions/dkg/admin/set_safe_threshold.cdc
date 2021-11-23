import FlowDKG from 0xDKGADDRESS

transaction(newThresholdPercentage: UFix64?) {

    let dkgAdmin: &FlowDKG.Admin

    prepare(signer: AuthAccount) {

        self.dkgAdmin = signer.borrow<&FlowDKG.Admin>(from: FlowDKG.AdminStoragePath)
            ?? panic("Could not borrow DKG Admin reference")

    }

    execute {

        self.dkgAdmin.setSafeSuccessThreshold(newThresholdPercentage: newThresholdPercentage)

    }

}