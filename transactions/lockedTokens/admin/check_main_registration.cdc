import FungibleToken from 0xFUNGIBLETOKENADDRESS
import FlowToken from 0xFLOWTOKENADDRESS

import LockedTokens from 0xLOCKEDTOKENADDRESS

transaction(mainAccount: Address) {

    prepare(signer: AuthAccount) {

        let adminRef = signer.borrow<&LockedTokens.TokenAdminCollection>(from: LockedTokens.LockedTokenAdminCollectionStoragePath)
            ?? panic("Could not borrow a reference to the locked token admin collection")

        let lockedAccountInfoRef = getAccount(mainAccount)
            .getCapability<&LockedTokens.TokenHolder{LockedTokens.LockedAccountInfo}>(LockedTokens.LockedAccountInfoPublicPath)
            .borrow()
            ?? panic("Could not borrow a reference to public LockedAccountInfo")

        let lockedAccount = lockedAccountInfoRef.getLockedAccountAddress()

        assert(
            adminRef.getAccount(address: lockedAccount) != nil,
            message: "The specified account is not a locked account! Cannot send locked tokens"
        )
    }
}
