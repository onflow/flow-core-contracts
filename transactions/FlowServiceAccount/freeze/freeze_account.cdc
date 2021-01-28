import FlowFreeze from 0xFREEZEADDRESS

transaction(address: Address) {

    prepare(signer: AuthAccount) {

        let freezeAdmin = signer.borrow<&FlowFreeze.Admin>(from: FlowFreeze.AdminStoragePath)
            ?? panic("Could not borrow admin reference")

        freezeAdmin.freezeAccount(address)
    }
    
}