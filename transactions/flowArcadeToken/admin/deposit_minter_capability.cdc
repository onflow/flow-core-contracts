/// token admin signs this transaction to deposit a capability
/// into a custody provider's account that allows them to add
/// accounts to the record

import FlowArcadeToken from 0xARCADETOKENADDRESS

transaction(minterAddress: Address) {

    let resourceStoragePath: Path
    let capabilityPrivatePath: Path
    let minterCapability: Capability<&FlowArcadeToken.Minter>

    prepare(adminAccount: AuthAccount) {

        // These paths must be unique within the FAT contract account's storage
        self.resourceStoragePath = /RESOURCESTORAGEPATH
        self.capabilityPrivatePath = /CAPABILITYPRIVATEPATH 

        // Create a reference to the admin resource in storage.
        let tokenAdmin = adminAccount.borrow<&FlowArcadeToken.Administrator>(from: FlowArcadeToken.AdminStoragePath)
            ?? panic("Could not borrow a reference to the admin resource")

        // Create a new minter resource and a private link to a capability for it in the admin's storage.
        let minter <- tokenAdmin.createNewMinter()
        adminAccount.save(<- minter, to: self.resourceStoragePath)
        self.minterCapability = adminAccount.link<&FlowArcadeToken.Minter>(
            self.capabilityPrivatePath,
            target: self.resourceStoragePath
        ) ?? panic("Could not link minter")

    }

    execute {

        // This is the account that the capability will be given to
        let minterAccount = getAccount(minterAddress)

        let capabilityReceiver = minterAccount.getCapability
            <&FlowArcadeToken.MinterProxy{FlowArcadeToken.MinterProxyPublic}>
            (FlowArcadeToken.MinterProxyPublicPath)!
            .borrow() ?? panic("Could not borrow capability receiver reference")

        capabilityReceiver.setMinterCapability(cap: self.minterCapability)

    }

}