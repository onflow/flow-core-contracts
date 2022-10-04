import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS

// This transaction sets the slot limits for each node type 

// slotLimits is a UInt16 array that contains the limit for
// each node type in order from 0-4. It is used to populate
// a dictionary that has keys shifted +1 so that they align
// with the enumerated node types from 1-5.

transaction(slotLimits: [UInt16]) {

    // Local variable for a reference to the ID Table Admin object
    let adminRef: &FlowIDTableStaking.Admin

    prepare(acct: AuthAccount) {
        // borrow a reference to the admin object
        self.adminRef = acct.borrow<&FlowIDTableStaking.Admin>(from: FlowIDTableStaking.StakingAdminStoragePath)
            ?? panic("Could not borrow reference to staking admin")
    }

    execute {
        // panic if we do not specify exactly one slot limit per node role
        if slotLimits.length != 5 {
            panic("transaction argument must specify one slot limit per node role")
        }

        var slotLimitDictionary: {UInt8: UInt16} = {}
        var dictionaryKey: UInt8 = 1

        for slotLimit in slotLimits {
            slotLimitDictionary.insert(key: dictionaryKey, slotLimit)
            dictionaryKey = dictionaryKey + 1
        }

        self.adminRef.setSlotLimits(slotLimits: slotLimitDictionary)
    }
}
