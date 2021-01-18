import LockedTokens from 0xLOCKEDTOKENADDRESS

/// token admin signs this transaction to deposit a capability
/// into a custody provider's account that allows them to add
/// accounts to the record

transaction(custodyProviderAddress: Address) {

    prepare(admin: AuthAccount) {

        let capabilityReceiver = getAccount(custodyProviderAddress)
            .getCapability<&LockedTokens.LockedAccountCreator{LockedTokens.LockedAccountCreatorPublic}>(
                LockedTokens.LockedAccountCreatorPublicPath
            )
            .borrow()
            ?? panic("Could not borrow capability receiver reference")

        let tokenAdminCollection = admin.getCapability<&LockedTokens.TokenAdminCollection>(
            LockedTokens.LockedTokenAdminPrivatePath
        )

        capabilityReceiver.addCapability(cap: tokenAdminCollection)
    }
}
