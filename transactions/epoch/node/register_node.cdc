import Crypto
import FlowIDTableStaking from "FlowIDTableStaking"
import FlowToken from "FlowToken"
import FlowClusterQC from 0xQCADDRESS
import FlowDKG from 0xDKGADDRESS
import FlowEpoch from 0xEPOCHADDRESS
import FungibleToken from "FungibleToken"

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
    publicKeys: [Crypto.KeyListEntry]
) {

    let flowTokenRef: auth(FungibleToken.Withdrawable) &FlowToken.Vault

    prepare(acct: auth(BorrowValue) &Account) {

        self.flowTokenRef = acct.storage.borrow<auth(FungibleToken.Withdrawable) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to FLOW Vault")

        // Register Node
        if acct.storage.borrow<&FlowIDTableStaking.NodeStaker>(from: FlowIDTableStaking.NodeStakerStoragePath) == nil {

            let nodeStaker <- FlowIDTableStaking.addNodeRecord(
                id: id,
                role: role,
                networkingAddress: networkingAddress,
                networkingKey: networkingKey,
                stakingKey: stakingKey,
                tokensCommitted: <-self.flowTokenRef.withdraw(amount: amount)
            )

            acct.storage.save(<-nodeStaker, to: FlowIDTableStaking.NodeStakerStoragePath)

            let nodeStakerCap = acct.capabilities.storage.issue<&{FlowIDTableStaking.NodeStakerPublic}>(FlowIDTableStaking.NodeStakerStoragePath)
            acct.capabilities.storage.publish(nodeStakerCap, to: FlowIDTableStaking.NodeStakerPublicPath)
        }

        let nodeRef = acct.borrow<&FlowIDTableStaking.NodeStaker>(from: FlowIDTableStaking.NodeStakerStoragePath)
            ?? panic("Could not borrow node reference from storage path")

        let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeRef.id)

        // If the node is a collector or consensus node, create a secondary account for their specific objects
        if nodeInfo.role == 1 as UInt8 {

            let machineAcct = Account(payer: acct)
            for key in publicKeys {
                machineAcct.keys.add(publicKey: key.publicKey, hashAlgorithm: key.hashAlgorithm, weight: key.weight)
            }

            let qcVoter <- FlowEpoch.getClusterQCVoter(nodeStaker: nodeRef)
            machineAcct.storage.save(<-qcVoter, to: FlowClusterQC.VoterStoragePath)

        } else if nodeInfo.role == 2 as UInt8 {

            let machineAcct = Account(payer: acct)
            for key in publicKeys {
                machineAcct.keys.add(publicKey: key.publicKey, hashAlgorithm: key.hashAlgorithm, weight: key.weight)
            }

            let dkgParticipant <- FlowEpoch.getDKGParticipant(nodeStaker: nodeRef)
            machineAcct.storage.save(<-dkgParticipant, to: FlowDKG.ParticipantStoragePath)
        }
    }
}