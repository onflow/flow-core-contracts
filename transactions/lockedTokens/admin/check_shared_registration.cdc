import "FungibleToken"
import "FlowToken"

import "LockedTokens"

transaction(lockedAccount: Address) {

    prepare(signer: auth(BorrowValue) &Account) {

        let adminRef = signer.storage.borrow<&LockedTokens.TokenAdminCollection>(from: LockedTokens.LockedTokenAdminCollectionStoragePath)
            ?? panic("Could not borrow a reference to the locked token admin collection")

        assert (
            adminRef.getAccount(address: lockedAccount) != nil,
            message: "The specified account is not a locked account! Cannot send locked tokens"
        )
    }
}
