import LockedTokens from 0xLOCKEDTOKENADDRESS

/// token admin signs this transaction to deposit a capability
/// into a custody provider's account that allows them to add
/// accounts to the record

transaction(custodyProviderAddress: Address) {

    prepare(admin: auth(BorrowValue) &Account) {

        let capabilityReceiver = getAccount(custodyProviderAddress)
            .capabilities.borrow<&LockedTokens.LockedAccountCreator>(
                LockedTokens.LockedAccountCreatorPublicPath
            )
            ?? panic("Could not borrow capability receiver reference")

        let tokenAdminCollection = admin.capabilities.get<&LockedTokens.TokenAdminCollection>(
            LockedTokens.LockedTokenAdminPrivatePath
        )!

        capabilityReceiver.addCapability(cap: tokenAdminCollection)
    }
}
