import FlowIDTableStaking from "FlowIDTableStaking"
import LockedTokens from "LockedTokens"

transaction {

    prepare(signer: auth(BorrowValue) &Account) {

        let managerRef = signer.storage.borrow<auth(LockedTokens.UnlockTokens) &LockedTokens.LockedTokenManager>(from: LockedTokens.LockedTokenManagerStoragePath)
            ?? panic("Could not borrow a reference to the locked token manager")

        let delegator <- managerRef.removeDelegator()!

        destroy delegator

    }
}
