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

	// create a map for existing node IDs to avoid double-adding
	let nodeIDsMap: {String: Bool} = {}	
	for nodeID in nodeIDs {
		nodeIDsMap[nodeID] = true
	}

	// remove each node 
	for nodeIDToRemove in ids {
		if nodeIDsMap[nodeIDToRemove] != nil {
			nodeIDsMap[nodeIDToRemove] = false
		} else {
			panic("attempted to remove non-existent node ID from allow-list: ".concat(nodeIDToRemove))
		}
	}

	// create a new node ID list, omitted those marked for deletion
	let newNodeIDs: [String] = []
	for nodeID in nodeIDs {
		if nodeIDsMap[nodeID]! == true {
			newNodeIDs.append(nodeID)
		}
	}

	// set the approved list to the new allow-list
        self.adminRef.setApprovedList(newNodeIDs)
    }
}