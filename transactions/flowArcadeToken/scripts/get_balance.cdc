// This script reads the balance field of an account's FlowArcadeToken Balance

import FungibleToken from 0xFUNGIBLETOKENADDRESS
import FlowArcadeToken from 0xARCADETOKENADDRESS

pub fun main(account: Address): UFix64 {
    let acct = getAccount(account)
    let vaultRef = acct.getCapability(/public/flowArcadeTokenBalance)!.borrow<&FlowArcadeToken.Vault{FungibleToken.Balance}>()
        ?? panic("Could not borrow Balance reference to the Vault")

    return vaultRef.balance
}
