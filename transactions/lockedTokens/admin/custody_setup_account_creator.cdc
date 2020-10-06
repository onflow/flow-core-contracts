import LockedTokens from 0xf3fcd2c1a78f5eee

transaction {

    prepare(admin: AuthAccount) {

        let accountCreator <- LockedTokens.createLockedAccountCreator()

        admin.save(
            <-accountCreator, 
            to: LockedTokens.LockedAccountCreatorStoragePath,
        )
            
        // create new receiver that marks received tokens as unlocked
        admin.link<&LockedTokens.LockedAccountCreator{LockedTokens.LockedAccountCreatorPublic}>(
            LockedTokens.LockedAccountCreatorPublicPath,
            target: LockedTokens.LockedAccountCreatorStoragePath
        )
    }
}
