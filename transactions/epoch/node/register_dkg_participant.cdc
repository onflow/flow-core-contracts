import FlowEpoch from 0xEPOCHADDRESS
import FlowIDTableStaking from "FlowIDTableStaking"
import FlowDKG from 0xDKGADDRESS

transaction() {

    prepare(signer: auth(Storage) &Account) {

        let nodeRef = signer.storage.borrow<&FlowIDTableStaking.NodeStaker>(from: FlowIDTableStaking.NodeStakerStoragePath)
            ?? panic("Could not borrow node reference from storage path")

        let dkgParticipant <- FlowEpoch.getDKGParticipant(nodeStaker: nodeRef)

        signer.storage.save(<-dkgParticipant, to: FlowDKG.ParticipantStoragePath)

    }
}