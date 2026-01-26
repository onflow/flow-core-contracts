// This script reads the balance field of an account's FlowToken Balance

import "EVM"

access(all) fun main(account: Address): EVM.Balance {

    let coaRef = getAccount(account)
        .capabilities.borrow<&EVM.CadenceOwnedAccount>(/public/evm)
        ?? panic("Could not borrow a balance reference to the COA in account "
                .concat(account.toString()).concat(" at path /public/evm. ")
                .concat("Make sure you are querying an address that has ")
                .concat("a COA set up properly at the specified path."))

    return coaRef.balance()
}
