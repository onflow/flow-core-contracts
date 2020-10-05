import LockedTokens from 0xf3fcd2c1a78f5eee

transaction {

    prepare(acct: AuthAccount) {
        let tokenAdminCollection <- LockedTokens.createTokenAdminCollection()

        acct.save(<-tokenAdminCollection, to: LockedTokens.LockedTokenAdminCollectionStoragePath)
    }
}