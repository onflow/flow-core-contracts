// import Lockbox from 0

transaction() {

    prepare(acct: AuthAccount) {
        let tokenAdminCollection <- LockBox.createTokenAdminCollection()

        acct.save(<-tokenAdminCollection, to: LockBox.LockedTokenAdminCollectionStoragePath)
    }
}