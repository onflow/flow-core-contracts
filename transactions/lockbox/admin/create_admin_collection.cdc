import Lockbox from 0xf3fcd2c1a78f5eee

transaction() {

    prepare(acct: AuthAccount) {
        let tokenAdminCollection <- LockBox.createTokenAdminCollection()

        acct.save(<-tokenAdminCollection, to: LockBox.LockedTokenAdminCollectionStoragePath)
    }
}