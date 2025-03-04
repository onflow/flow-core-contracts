import "FlowIDTableStaking"

// This transaction adds node IDs to the list of approved nodes in
// the ID table. 
// If any of the provided nodes already exist in the ID table, this
// transaction will not revert (idempotent)

transaction(ids: [String]) {

    // Local variable for a reference to the ID Table Admin object
    let adminRef: &FlowIDTableStaking.Admin

    prepare(acct: auth(BorrowValue) &Account) {
        // borrow a reference to the admin object
        self.adminRef = acct.storage.borrow<&FlowIDTableStaking.Admin>(from: FlowIDTableStaking.StakingAdminStoragePath)
            ?? panic("Could not borrow reference to staking admin")
    }

    execute {
		let nodeIDs = FlowIDTableStaking.getApprovedList()
            ?? panic("Could not read approve list from storage")

		// add any new node ID which doesn't already exist
		for newNodeID in ids {
			nodeIDs[newNodeID] = true
		}

		// set the approved list to the union of existing and new node IDs
        self.adminRef.setApprovedList(nodeIDs)
    }
}