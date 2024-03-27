
transaction(code: [UInt8]) {

    prepare(acct: auth(UpdateContract) &Account) {
        acct.contracts.update(name: "FlowIDTableStaking", code: code)
    }
}