import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS
import FlowToken from 0xFLOWTOKENADDRESS
import FlowEpochClusterQC from 0xQCADDRESS
import FlowDKG from 0xDKGADDRESS
import FlowEpoch from 0xEPOCHADDRESS

// This transaction creates a new node struct object
// Then, if the node is a collector node, creates a new account and adds a QC object to it
// If the node is a consensus node, it creates a new account and adds a DKG object to it

transaction(
    id: String,
    role: UInt8,
    networkingAddress: String,
    networkingKey: String,
    stakingKey: String,
    amount: UFix64,
    publicKeys: [String]
) {

    let flowTokenRef: &FlowToken.Vault

    prepare(acct: AuthAccount) {

        self.flowTokenRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to FLOW Vault")

        // Register Node
        if acct.borrow<&FlowIDTableStaking.NodeStaker>(from: FlowIDTableStaking.NodeStakerStoragePath) == nil {

            let nodeStaker <- FlowIDTableStaking.addNodeRecord(
                id: id,
                role: role,
                networkingAddress: networkingAddress,
                networkingKey: networkingKey,
                stakingKey: stakingKey,
                tokensCommitted: <-self.flowTokenRef.withdraw(amount: amount)
            )

            acct.save(<-nodeStaker, to: FlowIDTableStaking.NodeStakerStoragePath)

            acct.link<&{FlowIDTableStaking.NodeStakerPublic}>(
                FlowIDTableStaking.NodeStakerPublicPath,
                target: FlowIDTableStaking.NodeStakerStoragePath
            )
        }

        let nodeRef = signer.borrow<&FlowIDTableStaking.NodeStaker>(from: FlowIDTableStaking.NodeStakerStoragePath)
            ?? panic("Could not borrow node reference from storage path")

        let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeRef.id)

        // If the node is a collector or consensus node, create a secondary account for their specific objects
        if nodeInfo.role == 1 as UInt8 {

            let newAcct = AuthAccount(payer: newAcct)
            for key in publicKeys {
                newAcct.addPublicKey(key.decodeHex())
            }

            let qcVoter <- FlowEpoch.getClusterQCVoter(nodeStaker: nodeRef)

            signer.save(<-qcVoter, to: FlowEpochClusterQC.VoterStoragePath)

        } else if nodeInfo.role == 2 as UInt8 {

            let newAcct = AuthAccount(payer: newAcct)
            for key in publicKeys {
                newAcct.addPublicKey(key.decodeHex())
            }

            let dkgParticipant <- FlowEpoch.getDKGParticipant(nodeStaker: nodeRef)

            signer.save(<-dkgParticipant, to: FlowDKG.ParticipantStoragePath)

        }

    }
}