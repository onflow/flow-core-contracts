import FlowToken from "FlowToken"
import FungibleToken from "FungibleToken"
import LockedTokens from "LockedTokens"
import StakingProxy from "StakingProxy"

transaction(id: String,
            role: UInt8,
            networkingAddress: String,
            networkingKey: String,
            stakingKey: String,
            stakingKeyPoP: String,
            amount: UFix64) {

    let holderRef: auth(LockedTokens.TokenOperations, FungibleToken.Withdraw) &LockedTokens.TokenHolder

    let vaultRef: auth(FungibleToken.Withdraw) &FlowToken.Vault

    prepare(account: auth(BorrowValue) &Account) {
        self.holderRef = account.storage.borrow<auth(LockedTokens.TokenOperations, FungibleToken.Withdraw) &LockedTokens.TokenHolder>(from: LockedTokens.TokenHolderStoragePath)
            ?? panic("Could not borrow ref to TokenHolder")

        self.vaultRef = account.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow flow token vault reference")
    }

    execute {
        let nodeInfo = StakingProxy.NodeInfo(
          nodeID: id,
          role: role,
          networkingAddress: networkingAddress,
          networkingKey: networkingKey,
          stakingKey: stakingKey
        )

        let lockedBalance = self.holderRef.getLockedAccountBalance()

        if amount <= lockedBalance {

            self.holderRef.createNodeStaker(nodeInfo: nodeInfo, stakingKeyPoP: stakingKeyPoP, amount: amount)

        } else if ((amount - lockedBalance) <= self.vaultRef.balance) {

            self.holderRef.deposit(from: <-self.vaultRef.withdraw(amount: amount - lockedBalance))

            self.holderRef.createNodeStaker(nodeInfo: nodeInfo, stakingKeyPoP: stakingKeyPoP, amount: amount)

        } else {
            panic("Not enough tokens to stake!")
        }
        
    }
}
