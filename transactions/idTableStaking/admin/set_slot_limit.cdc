import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This transaction sets the slot limits for each node type 

transaction(slotLimits: [UInt8]) {

    // Local variable for a reference to the ID Table Admin object
    let adminRef: &FlowIDTableStaking.Admin

    prepare(acct: AuthAccount) {
        // borrow a reference to the admin object
        self.adminRef = acct.borrow<&FlowIDTableStaking.Admin>(from: FlowIDTableStaking.StakingAdminStoragePath)
            ?? panic("Could not borrow reference to staking admin")
    }

    execute {
        var slotLimitDictionary: {UInt8: UInt8} = {}
        var dictionaryKey: UInt8 = 1

        for slotLimit in slotLimits {
            slotLimitDictionary.insert(key: dictionaryKey, slotLimit)
            dictionaryKey = dictionaryKey + 1
        }

        self.adminRef.setSlotLimits(slotLimits: slotLimitDictionary)
    }
}
