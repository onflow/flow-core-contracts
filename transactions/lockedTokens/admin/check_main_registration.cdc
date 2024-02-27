import FungibleToken from "FungibleToken"
import FlowToken from "FlowToken"

import LockedTokens from "LockedTokens"

transaction(mainAccount: Address) {

    prepare(signer: auth(BorrowValue) &Account) {

        let adminRef = signer.storage.borrow<&LockedTokens.TokenAdminCollection>(from: LockedTokens.LockedTokenAdminCollectionStoragePath)
            ?? panic("Could not borrow a reference to the locked token admin collection")

        let lockedAccountInfoRef = getAccount(mainAccount)
            .capabilities.borrow<&LockedTokens.TokenHolder>(LockedTokens.LockedAccountInfoPublicPath)
            ?? panic("Could not borrow a reference to public LockedAccountInfo")

        let lockedAccount = lockedAccountInfoRef.getLockedAccountAddress()

        assert(
            adminRef.getAccount(address: lockedAccount) != nil,
            message: "The specified account is not a locked account! Cannot send locked tokens"
        )
    }
}
