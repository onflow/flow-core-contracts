import LockedTokens from 0xLOCKEDTOKENADDRESS

transaction {

    prepare(custodyProvider: AuthAccount) {

        let accountCreator <- LockedTokens.createLockedAccountCreator()

        custodyProvider.save(
            <-accountCreator, 
            to: LockedTokens.LockedAccountCreatorStoragePath,
        )
            
        // create new receiver that marks received tokens as unlocked
        custodyProvider.link<&LockedTokens.LockedAccountCreator{LockedTokens.LockedAccountCreatorPublic}>(
            LockedTokens.LockedAccountCreatorPublicPath,
            target: LockedTokens.LockedAccountCreatorStoragePath
        )
    }
}
