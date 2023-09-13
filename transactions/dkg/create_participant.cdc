import FlowDKG from 0xDKGADDRESS

transaction(address: Address, nodeID: String) {

    prepare(signer: auth(SaveValue) &Account) {
        let admin = getAccount(address).capabilities.get<&FlowDKG.Admin>(/public/dkgAdmin)!
            .borrow() ?? panic("Could not borrow admin reference")

        let dkgParticipant <- admin.createParticipant(nodeID: nodeID)

        signer.storage.save(<-dkgParticipant, to: FlowDKG.ParticipantStoragePath)
    }

}