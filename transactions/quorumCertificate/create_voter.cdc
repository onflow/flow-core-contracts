import FlowClusterQC from 0xQCADDRESS

// Test Transaction for a node to request a QC Voter Object from the contract
// Will be updated to use the epoch contract when that is completed
// The voter object only needs to be created once and is valid for every future epoch
// where the node is a valid staked node

// Parameters:
// 
// adminAddress: the address of the QC admin to request the Voter from
// nodeID: the id of the node that the account is operating
// stakingKey: The staking key for the collector node

transaction(adminAddress: Address, nodeID: String, stakingKey: String) {

    prepare(signer: AuthAccount) {

        // Get the admin reference from the admin account
        let admin = getAccount(adminAddress)
        let adminRef = admin.getCapability<&FlowClusterQC.Admin>(/public/voterCreator)!
            .borrow() ?? panic("Could not borrow a reference to the admin")

        // Create a voter object and save it to storage
        let voter <- adminRef.createVoter(nodeID: nodeID, stakingKey: stakingKey)

        signer.save(<-voter, to: FlowClusterQC.VoterStoragePath)
    }
}