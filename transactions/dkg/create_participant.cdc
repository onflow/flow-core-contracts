import FlowDKG from 0xDKGADDRESS

transaction(address: Address, nodeID: String) {

    prepare(signer: AuthAccount) {
        let admin = getAccount(address).getCapability<&FlowDKG.Admin>(/public/dkgAdmin)

        let dkgParticipant <- admin.createParticipant(nodeID)

        signer.save(<-dkgParticipant, to: FlowDKG.ParticipantStoragePath)
    }

}