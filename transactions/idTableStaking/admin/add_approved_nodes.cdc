import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This transaction adds node IDs to the list of approved nodes in
// the ID table. 
// If any of the provided nodes already exist in the ID table, this
// transaction will not revert (idempotent)

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

	// create a map for existing node IDs to avoid double-adding
	let nodeIDsMap: {String: Bool} = {}	
	for nodeID in nodeIDs {
		nodeIDsMap[nodeID] = true
	}

	// add any new node ID which doesn't already exist
	for newNodeID in ids {
		if nodeIDsMap[newNodeID] == nil {
			nodeIDs.append(newNodeID)
		}
	}

	// set the approved list to the union of existing and new node IDs
        self.adminRef.setApprovedList(nodeIDs)
    }
}