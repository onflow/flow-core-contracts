import FlowArcadeToken from 0xARCADETOKENADDRESS

transaction() {
    
    prepare(adminAcct: AuthAccount, minterAcct: AuthAccount) {
        // Create a reference to the admin resource in storage
       let tokenAdmin = adminAcct.borrow<&FlowArcadeToken.Administrator>(from: /storage/flowArcadeTokenAdmin)
            ?? panic("Could not borrow a reference to the admin resource")

        // Create a new minter and a private link to it
        let minter <- tokenAdmin.createNewMinter()
        adminAcct.save(<- minter, to: /storage/flowArcadeTokenMinter)
        let minterCap = adminAcct.link<&FlowArcadeToken.Minter>(
            /private/flowArcadeTokenMinter,
            target: /storage/flowArcadeTokenMinter
        )!

        // Transfer the capability to the minter account
        minterAcct.save(minterCap, to: /storage/flowArcadeTokenMinter)
    }

}
