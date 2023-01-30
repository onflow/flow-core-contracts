import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

/// This transaction adds node IDs to the list of approved nodes in
/// the ID table. 
/// It also increases the candidate node limit and slot limits
/// by the number of nodes who are added
///
/// If any of the provided nodes already exist in the ID table, this
/// transaction will not revert (idempotent)

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

		let candidateNodeLimits = FlowIDTableStaking.getCandidateNodeLimits()
			?? panic("Could not load candidate node limits")

		let slotLimits = FlowIDTableStaking.getRoleSlotLimits()

		// add any new node ID which doesn't already exist in the approve list
		// and increase the candidate node limits and slot limits by 1
		// for each corresponding node added
		for newNodeID in ids {
			let nodeInfo = FlowIDTableStaking.NodeInfo(newNodeID)

			candidateNodeLimits[nodeInfo.role] = candidateNodeLimits[nodeInfo.role]! + 1

			slotLimits[nodeInfo.role] = slotLimits[nodeInfo.role]! + 1

			nodeIDs[newNodeID] = true
		}

		// set the approved list to the union of existing and new node IDs
        self.adminRef.setApprovedList(nodeIDs)

		// Set new slot limits
		self.adminRef.setSlotLimits(slotLimits: slotLimits)

		// Set new candidate node limits
		for role in candidateNodeLimits.keys {
			self.adminRef.setCandidateNodeLimit(role: role, newLimit: candidateNodeLimits[role]!)
		}
    }
}