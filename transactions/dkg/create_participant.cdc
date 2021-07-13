import FlowDKG from 0xDKGADDRESS

transaction(address: Address, nodeID: String) {

    prepare(signer: AuthAccount) {
        let admin = getAccount(address).getCapability<&FlowDKG.Admin>(/public/dkgAdmin)
            .borrow() ?? panic("Could not borrow admin reference")

        let dkgParticipant <- admin.createParticipant(nodeID: nodeID)

        signer.save(<-dkgParticipant, to: FlowDKG.ParticipantStoragePath)
    }

}