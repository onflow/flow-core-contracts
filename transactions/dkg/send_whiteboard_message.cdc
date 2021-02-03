import FlowDKG from 0xDKGADDRESS

transaction(content: String) {

    let dkgParticipant: &FlowDKG.Participant

    prepare(signer: AuthAccount) {
        self.dkgParticipant = signer.borrow<&FlowDKG.Participant>(from: FlowDKG.ParticipantStoragePath)
            ?? panic("Cannot borrow dkg participant reference")
    }

    execute {

        self.dkgParticipant.postMessage(content)

    }

}