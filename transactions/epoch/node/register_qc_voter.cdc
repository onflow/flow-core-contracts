import FlowEpoch from 0xEPOCHADDRESS
import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS
import FlowEpochClusterQC from 0xQCADDRESS

transaction() {

    prepare(signer: AuthAccount) {

        let nodeRef = signer.borrow<&FlowIDTableStaking.NodeStaker>(from: FlowIDTableStaking.NodeStakerStoragePath)
            ?? panic("Could not borrow node reference from storage path")

        let qcVoter <- FlowEpoch.getClusterQCVoter(nodeStaker: nodeRef)

        signer.save(<-qcVoter, to: FlowEpochClusterQC.VoterStoragePath)

    }
}