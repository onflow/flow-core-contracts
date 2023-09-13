// This script reads the balance field of an account's FlowToken Balance

import FungibleToken from "FungibleToken"
import FlowToken from "FlowToken"

access(all) fun main(account: Address): UFix64 {

    let vaultRef = getAccount(account)
        .capabilities.get<&FlowToken.Vault{FungibleToken.Balance}>(/public/flowTokenBalance)!
        .borrow()
        ?? panic("Could not borrow Balance reference to the Vault")

    return vaultRef.balance
}
