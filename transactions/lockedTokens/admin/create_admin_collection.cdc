import LockedTokens from 0xLOCKEDTOKENADDRESS

transaction {

    prepare(acct: AuthAccount) {
        let tokenAdminCollection <- LockedTokens.createTokenAdminCollection()

        acct.save(<-tokenAdminCollection, to: LockedTokens.LockedTokenAdminCollectionStoragePath)
    }
}
