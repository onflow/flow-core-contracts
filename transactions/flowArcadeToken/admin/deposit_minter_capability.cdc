/// token admin signs this transaction to deposit a capability
/// into a custody provider's account that allows them to add
/// accounts to the record

import FlowArcadeToken from 0xARCADETOKENADDRESS

transaction(minterAddress: Address) {
    let minterCapability: Capability<&{FlowArcadeToken.Minter}>

    prepare(adminAccount: AuthAccount) {

        self.minterCapability = adminAccount.getCapability<&{FlowArcadeToken.Minter}>(
            FlowArcadeToken.AdminMinterPrivatePath
        ) ?? panic("Couldn't access Minter capability path.")
        
        // If we got an invalid capability we do not want to set that on the proxy
        assert(self.minterCapability.check(), message: "Minter capability didn't check.")

    }

    execute {

        // This is the account that the capability will be given to
        let minterAccount = getAccount(minterAddress)

        let capabilityReceiver = minterAccount
            .getCapability<&FlowArcadeToken.MinterProxy{FlowArcadeToken.MinterProxyPublic}>(
                FlowArcadeToken.MinterProxyPublicPath
            )!
            .borrow()
            ?? panic("Could not borrow capability receiver reference")

        capabilityReceiver.setMinterCapability(cap: self.minterCapability)

    }

}