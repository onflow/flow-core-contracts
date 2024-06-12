import LockedTokens from "LockedTokens"

/// token admin signs this transaction to deposit a capability
/// into a custody provider's account that allows them to add
/// accounts to the record

transaction(custodyProviderAddress: Address) {

    prepare(admin: auth(BorrowValue, Capabilities) &Account) {

        let capabilityReceiver = getAccount(custodyProviderAddress)
            .capabilities.borrow<&LockedTokens.LockedAccountCreator>(
                LockedTokens.LockedAccountCreatorPublicPath
            )
            ?? panic("Could not borrow capability receiver reference")

        let tokenAdminCollection = admin.capabilities.storage.issue<auth(LockedTokens.AccountCreator) &LockedTokens.TokenAdminCollection>(
            LockedTokens.LockedTokenAdminCollectionStoragePath
        )!

        capabilityReceiver.addCapability(cap: tokenAdminCollection)
    }
}
