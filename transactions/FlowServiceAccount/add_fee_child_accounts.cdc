import "FlowFees"

/// Creates the given number of new child fee accounts, paid for by the
/// signer, and registers them in FlowFees as accounts that may receive
/// transaction fee deposits.
/// Must be signed by the account which holds the FlowFees Administrator.
transaction(accounts: Int) {
    prepare(admin: auth(BorrowValue) &Account) {
        let flowFeesAdmin = admin.storage.borrow<&FlowFees.Administrator>(from: /storage/flowFeesAdmin)
            ?? panic("Could not borrow a reference to the FlowFees Administrator from /storage/flowFeesAdmin")

        flowFeesAdmin.createChildFeeAccounts(count: accounts, payer: admin)
    }
}
