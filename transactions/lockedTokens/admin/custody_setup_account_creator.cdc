import "LockedTokens"

transaction {

    prepare(custodyProvider: auth(SaveValue, Capabilities) &Account) {

        let accountCreator <- LockedTokens.createLockedAccountCreator()

        custodyProvider.storage.save(
            <-accountCreator,
            to: LockedTokens.LockedAccountCreatorStoragePath
        )

        // create new receiver that marks received tokens as unlocked
        let lockedAccountCreatorCap = custodyProvider.capabilities.storage.issue<&LockedTokens.LockedAccountCreator>(
            LockedTokens.LockedAccountCreatorStoragePath
        )

        custodyProvider.capabilities.publish(
            lockedAccountCreatorCap,
            at: LockedTokens.LockedAccountCreatorPublicPath
        )
    }
}
