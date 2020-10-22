///////////////////////////////////////////
//NOTE: SEE capabilityStoragePath BELOW! //
///////////////////////////////////////////

import FlowArcadeToken from 0xARCADETOKENADDRESS

transaction() {
    
    prepare(adminAcct: AuthAccount, minterAcct: AuthAccount) {

        // Create a unique path to a minter for an account.
        // We can delete the capability at this path if needed to revoke the minting capability for that account.
        // Increase these by one to the same value for each new minter created, and note which one belongs to which account.
        let minterStoragePath = /storage/flowArcadeTokenMinter000
        let minterCapabilityStoragePath = /private/flowArcadeTokenMinter000

        // Create a reference to the admin resource in storage.
        let tokenAdmin = adminAcct.borrow<&FlowArcadeToken.Administrator>(from: /storage/flowArcadeTokenAdmin)
            ?? panic("Could not borrow a reference to the admin resource")

        // Create a new minter resource and a private link to a capability for it in the admin's storage.
        let minter <- tokenAdmin.createNewMinter()
        adminAcct.save(<- minter, to: minterStoragePath)
        let minterCapability = adminAcct.link<&FlowArcadeToken.Minter>(
            minterCapabilityStoragePath,
            target: minterStoragePath
        ) ?? panic("Could not link minter")

        // Create a new minter proxy resource and save it to the minter account.
        let minterProxy <- tokenAdmin.createNewMinterProxy(minterCapability: minterCapability)
        // This is always the same for each minter account.
        minterAcct.save(<- minterProxy, to: /storage/flowArcadeTokenMinter)

    }

}
