import FlowDKG from 0xDKGADDRESS

transaction(phase: UInt8, content: String)) {

    let dkgParticipant: &FlowDKG.Participant

    prepare(signer: AuthAccount) {
        self.dkgParticipant = signer.borrow<&FlowDKG.Participant>(from: FlowDKG.ParticipantStoragePath)
    }

    execute {

        let dkgPhase: FlowDKG.DKGPhase = FlowDKG.DKGPhase(rawValue: phase)

        self.dkgParticipant.sendMessage(phase: phase, _ content: content)

    }

}