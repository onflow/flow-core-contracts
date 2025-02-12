import "FlowIDTableStaking"

/// This transaction sets the open node slots for access nodes
/// Open node slots are the number of slots that are open
/// each epoch, regardless of how many nodes joined in the previous epoch.
/// They are refreshed each epoch

transaction(openAccessSlots: UInt16) {

    // Local variable for a reference to the ID Table Admin object
    let adminRef: &FlowIDTableStaking.Admin

    prepare(acct: auth(BorrowValue) &Account) {
        // borrow a reference to the admin object
        self.adminRef = acct.storage.borrow<&FlowIDTableStaking.Admin>(from: FlowIDTableStaking.StakingAdminStoragePath)
            ?? panic("Could not borrow reference to staking admin")
    }

    execute {

        var openSlotDictionary: {UInt8: UInt16} = {}

        openSlotDictionary.insert(key: 5, openAccessSlots)

        self.adminRef.setOpenNodeSlots(openSlots: openSlotDictionary)
    }
}