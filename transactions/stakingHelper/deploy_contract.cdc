transaction (code: [UInt8]) {
    prepare(acct: AuthAccount ) {
        acct.setCode(code)
    }
}


// working solution
/*
transaction(code: [UInt8]) {
    prepare(signer: AuthAccount){
        let acct = AuthAccount(payer: signer)
    }
}
*/