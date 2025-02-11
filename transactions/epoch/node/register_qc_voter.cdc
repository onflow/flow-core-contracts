import "FlowEpoch"
import "FlowIDTableStaking"
import "FlowClusterQC"

transaction() {

    prepare(signer: auth(Storage) &Account) {

        let nodeRef = signer.storage.borrow<&FlowIDTableStaking.NodeStaker>(from: FlowIDTableStaking.NodeStakerStoragePath)
            ?? panic("Could not borrow node reference from storage path")

        let qcVoter <- FlowEpoch.getClusterQCVoter(nodeStaker: nodeRef)

        signer.storage.save(<-qcVoter, to: FlowClusterQC.VoterStoragePath)

    }
}