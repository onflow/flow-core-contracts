// Minter account signs this to set up the capability receiver for their minting capability
// Once this is run, the admin account runs deposit_minter_capability for this account's
// address to deposit the minter capability within it.
// The minter can then mint tokens using mint_tokens.cdc

import FlowArcadeToken from 0xARCADETOKENADDRESS

transaction {

    prepare(minter: AuthAccount) {

        let minterProxy <- FlowArcadeToken.createMinterProxy()

        minter.save(
            <- minterProxy, 
            to: FlowArcadeToken.MinterProxyStoragePath,
        )
            
        // create new receiver that marks received tokens as unlocked
        minter.link<&FlowArcadeToken.MinterProxy{FlowArcadeToken.MinterProxyPublic}>(
            FlowArcadeToken.MinterProxyPublicPath,
            target: FlowArcadeToken.MinterProxyStoragePath
        )

    }

}
