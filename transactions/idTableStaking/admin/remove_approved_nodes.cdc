import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This transaction removes node IDs from the list of approved nodes in
// the ID table. 
// If any of the IDs DO NOT exist already in the identity table, this
// transaction will revert (not idempotent)

transaction(ids: [String]) {

    // Local variable for a reference to the ID Table Admin object
    let adminRef: &FlowIDTableStaking.Admin

    prepare(acct: AuthAccount) {
        // borrow a reference to the admin object
        self.adminRef = acct.borrow<&FlowIDTableStaking.Admin>(from: FlowIDTableStaking.StakingAdminStoragePath)
            ?? panic("Could not borrow reference to staking admin")
    }

    execute {
	let nodeIDs = FlowIDTableStaking.getApprovedList()
        ?? panic("Could not read approve list from storage")

	// remove each node 
	for nodeIDToRemove in ids {
		nodeIDs[nodeIDToRemove] = nil
	}

	// set the approved list to the new allow-list
        self.adminRef.setApprovedList(nodeIDs)
    }
}