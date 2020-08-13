import FlowIdentityTable from 0xIDENTITYTABLEADDRESS

// This transaction creates a new node struct object
// and updates the proposed Identity Table

transaction(id: String, role: UInt8, networkingAddress: String, networkingKey: String, stakingKey: String, initialWeight: UInt64, counter: UInt64) {

    // Local variable for a reference to the ID Table Admin object
    let adminRef: &FlowIdentityTable.Admin

    prepare(acct: AuthAccount) {
        // borrow a reference to the admin object
        self.adminRef = acct.borrow<&FlowIdentityTable.Admin>(from: /storage/flowIdentityTableAdmin)
            ?? panic("Could not borrow reference to ID Table admin")
    }

    execute {
        let newNode = FlowIdentityTable.Node(id: id, role: role, networkingAddress: networkingAddress, networkingKey: networkingKey, stakingKey: stakingKey, initialWeight: initialWeight)

        self.adminRef.addProposedNode(epochCounter: counter, newNode)
    }
}