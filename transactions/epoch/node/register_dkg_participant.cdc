import FlowEpoch from 0xEPOCHADDRESS
import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS
import FlowDKG from 0xDKGADDRESS

transaction() {

    prepare(signer: AuthAccount) {

        let nodeRef = signer.borrow<&FlowIDTableStaking.NodeStaker>(from: FlowIDTableStaking.NodeStakerStoragePath)
            ?? panic("Could not borrow node reference from storage path")

        let dkgParticipant <- FlowEpoch.getDKGParticipant(nodeStaker: nodeRef)

        signer.save(<-dkgParticipant, to: FlowDKG.ParticipantStoragePath)

    }
}