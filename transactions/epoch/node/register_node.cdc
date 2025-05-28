import Crypto
import "FlowIDTableStaking"
import "FlowToken"
import "FlowClusterQC"
import "FlowDKG"
import "FlowEpoch"
import "FungibleToken"

// This transaction creates a new node struct object
// Then, if the node is a collector node, creates a new account and adds a QC object to it
// If the node is a consensus node, it creates a new account and adds a DKG object to it

transaction(
    id: String,
    role: UInt8,
    networkingAddress: String,
    networkingKey: String,
    stakingKey: String,
    stakingKeyPoP: String,
    amount: UFix64,
    publicKeys: [Crypto.KeyListEntry]
) {

    let flowTokenRef: auth(FungibleToken.Withdraw) &FlowToken.Vault

    prepare(acct: auth(Storage, Capabilities, AddKey) &Account) {

        self.flowTokenRef = acct.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to FLOW Vault")

        // Register Node
        if acct.storage.borrow<&FlowIDTableStaking.NodeStaker>(from: FlowIDTableStaking.NodeStakerStoragePath) == nil {

            let nodeStaker <- FlowIDTableStaking.addNodeRecord(
                id: id,
                role: role,
                networkingAddress: networkingAddress,
                networkingKey: networkingKey,
                stakingKey: stakingKey,
                stakingKeyPoP: stakingKeyPoP,
                tokensCommitted: <-self.flowTokenRef.withdraw(amount: amount)
            )

            acct.storage.save(<-nodeStaker, to: FlowIDTableStaking.NodeStakerStoragePath)

            let nodeStakerCap = acct.capabilities.storage.issue<&{FlowIDTableStaking.NodeStakerPublic}>(FlowIDTableStaking.NodeStakerStoragePath)
            acct.capabilities.publish(nodeStakerCap, at: FlowIDTableStaking.NodeStakerPublicPath)
        }

        let nodeRef = acct.storage.borrow<&FlowIDTableStaking.NodeStaker>(from: FlowIDTableStaking.NodeStakerStoragePath)
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