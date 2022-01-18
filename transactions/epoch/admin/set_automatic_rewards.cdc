import FlowEpoch from 0xEPOCHADDRESS

transaction(automaticRewardsEnabled: Bool) {
    prepare(signer: AuthAccount) {
        let epochAdmin = signer.borrow<&FlowEpoch.Admin>(from: FlowEpoch.adminStoragePath)
            ?? panic("Could not borrow admin from storage path")

        epochAdmin.updateAutomaticRewardsEnabled(automaticRewardsEnabled)
    }
}