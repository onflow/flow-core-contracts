import LockedTokens from 0xLOCKEDTOKENADDRESS

transaction {

    prepare(admin: AuthAccount) {
        let tokenAdminCollection <- LockedTokens.createTokenAdminCollection()

        admin.save(<-tokenAdminCollection, to: LockedTokens.LockedTokenAdminCollectionStoragePath)

        admin.link<&LockedTokens.TokenAdminCollection>(
            LockedTokens.LockedTokenAdminPrivatePath, 
            target: LockedTokens.LockedTokenAdminCollectionStoragePath
        )
            ?? panic("Could not get a capability to the admin collection")
    }
}
