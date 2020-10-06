import LockedTokens from 0xf3fcd2c1a78f5eee

/// token admin signs this transaction to deposit a capability
/// into a custody provider's account that allows them to add
/// accounts to the record

transaction(custodyProviderAddress: Address) {

    prepare(admin: AuthAccount) {

        let custodyProvider = getAccount(custodyProviderAddress)
            
        let capabilityReceiver = custodyProvider.getCapability
            <&LockedTokens.LockedAccountCreator{LockedTokens.LockedAccountCreatorPublic}>
            (LockedTokens.LockedAccountCreatorPublicPath)!
            .borrow() ?? panic("Could not borrow capability receiver reference")

        let tokenAdminCollection = admin.link<&LockedTokens.TokenAdminCollection>(LockedTokens.LockedTokenAdminPrivatePath, target: LockedTokens.LockedTokenAdminCollectionStoragePath)
            ?? panic("Could not get a capability to the admin collection")

        capabilityReceiver.addCapability(cap: tokenAdminCollection)
    }
}
