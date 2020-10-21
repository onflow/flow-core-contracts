import FungibleToken from 0xFUNGIBLETOKENADDRESS
import FlowToken from 0xFLOWTOKENADDRESS

import LockedTokens from 0xLOCKEDTOKENADDRESS

transaction(to: Address) {

    prepare(signer: AuthAccount) {

        let adminRef = signer.borrow<&LockedTokens.TokenAdminCollection>(from: LockedTokens.LockedTokenAdminCollectionStoragePath)
            ?? panic("Could not borrow a reference to the locked token admin collection")

        assert (
            adminRef.getAccount(address: to) != nil,
            message: "The specified account is not a locked account! Cannot send locked tokens"
        )
    }
}
