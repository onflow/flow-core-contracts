import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS
import LockedTokens from 0xLOCKEDTOKENADDRESS

transaction {

    prepare(signer: auth(BorrowValue) &Account) {

        let managerRef = signer.storage.borrow<&LockedTokens.LockedTokenManager>(from: LockedTokens.LockedTokenManagerStoragePath)
            ?? panic("Could not borrow a reference to the locked token manager")

        let delegator <- managerRef.removeDelegator()!

        destroy delegator

    }
}
