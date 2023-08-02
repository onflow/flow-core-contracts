import FlowToken from "FlowToken"
import LockedTokens from 0xLOCKEDTOKENADDRESS
import FlowIDTableStaking from "FlowIDTableStaking"
import FungibleToken from "FungibleToken"

transaction(id: String, amount: UFix64) {

    let holderRef: &LockedTokens.TokenHolder

    let vaultRef: &FlowToken.Vault

    prepare(account: AuthAccount) {
        self.holderRef = account.borrow<&LockedTokens.TokenHolder>(from: LockedTokens.TokenHolderStoragePath) 
            ?? panic("TokenHolder is not saved at specified path")

        self.vaultRef = account.borrow<auth(FungibleToken.Withdrawable) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow flow token vault reference")
    }

    execute {
        let lockedBalance = self.holderRef.getLockedAccountBalance()

        if amount <= lockedBalance {

            self.holderRef.createNodeDelegator(nodeID: id)

            let stakerProxy = self.holderRef.borrowDelegator()

            stakerProxy.delegateNewTokens(amount: amount - FlowIDTableStaking.getDelegatorMinimumStakeRequirement())

        } else if ((amount - lockedBalance) <= self.vaultRef.balance) {

            self.holderRef.deposit(from: <-self.vaultRef.withdraw(amount: amount - lockedBalance))

            self.holderRef.createNodeDelegator(nodeID: id)

            let stakerProxy = self.holderRef.borrowDelegator()

            stakerProxy.delegateNewTokens(amount: amount - FlowIDTableStaking.getDelegatorMinimumStakeRequirement())

        } else {
            panic("Not enough tokens to stake!")
        }
    }
}
