import FlowArcadeToken from 0xARCADETOKENADDRESS

transaction() {
    
    prepare(adminAcct: AuthAccount, minterAcct: AuthAccount) {
        // Create a reference to the admin admin resource in storage
       let tokenAdmin: &FlowArcadeToken.Administrator = adminAcct.borrow<&FlowArcadeToken.Administrator>(from: /storage/flowArcadeTokenAdmin)
            ?? panic("Could not borrow a reference to the admin resource")

        // Create a new minter and a private link to it
        let minter: @FlowArcadeToken.Minter <- tokenAdmin.createNewMinter()
        adminAcct.save<@FlowArcadeToken.Minter>(<- minter, to: /storage/flowArcadeTokenMinter)
        let minterCap: Capability<&FlowArcadeToken.Minter> = adminAcct.link<&FlowArcadeToken.Minter>(
            /private/flowArcadeTokenMinter,
            target: /storage/flowArcadeTokenMinter
        )!

        // Transfer the capability to the minter account
        minterAcct.save<Capability<&FlowArcadeToken.Minter> >(minterCap, to: /storage/flowArcadeTokenMinter)
    }

}
