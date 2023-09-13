import LockedTokens from 0xLOCKEDTOKENADDRESS
import FlowToken from "FlowToken"

transaction(amount: UFix64) {

    let holderRef: &LockedTokens.TokenHolder
    let vaultRef: &FlowToken.Vault

    prepare(account: auth(BorrowValue) &Account) {
        self.holderRef = account.storage.borrow<&LockedTokens.TokenHolder>(from: LockedTokens.TokenHolderStoragePath)
            ?? panic("Could not borrow reference to TokenHolder")

        self.vaultRef = account.storage.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to FlowToken value")
    }

    execute {
        let delegatorProxy = self.holderRef.borrowDelegator()

        delegatorProxy.withdrawRewardedTokens(amount: amount)
        self.vaultRef.deposit(from: <-self.holderRef.withdraw(amount: amount))
    }
}
