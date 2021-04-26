
transaction(code: [UInt8]) {

    prepare(acct: AuthAccount) {

        acct.contracts.update__experimental(name: "FlowIDTableStaking", code: code)
    }
}