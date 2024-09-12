import FlowIDTableStaking from 0x9eca2b38b18b5dfe 

/// Sets slots limits for each node role

transaction(role: UInt8, amountToIncrease: UInt16) {

    prepare(stakingAccount: AuthAccount) {

        // Initialize Candidate Node List
        let slotLimits: {UInt8: UInt16} = FlowIDTableStaking.getRoleSlotLimits()

        // Borrow the admin
        let adminRef = stakingAccount.borrow<&FlowIDTableStaking.Admin>(from: FlowIDTableStaking.StakingAdminStoragePath)
            ?? panic("Could not borrow reference to staking admin")

        var limit = slotLimits[role] ?? panic("Could not get the limit for the specified role")
        limit = limit + amountToIncrease
        slotLimits[role] = limit

        adminRef.setSlotLimits(slotLimits: slotLimits)
    }
}
