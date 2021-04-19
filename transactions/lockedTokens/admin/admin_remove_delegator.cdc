import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS
import LockedTokens from 0xLOCKEDTOKENADDRESS

transaction {

    prepare(signer: AuthAccount) {

        let managerRef = signer.borrow<&LockedTokens.LockedTokenManager>(from: LockedTokens.LockedTokenManagerStoragePath)
            ?? panic("Could not borrow a reference to the locked token manager")

        let delegator <- managerRef.removeDelegator()!

        destroy delegator

    }
}
