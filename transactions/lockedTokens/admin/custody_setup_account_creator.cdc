import LockedTokens from 0xLOCKEDTOKENADDRESS

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
