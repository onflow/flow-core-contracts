import "FungibleToken"
import "FlowToken"
import "LockedTokens"

transaction(amount: UFix64, to: Address) {

    // The Vault resource that holds the tokens that are being transferred
    let sentVault: @{FungibleToken.Vault}

    prepare(signer: auth(BorrowValue) &Account) {

        // Get a reference to the signer's locked token manager
        let tokenManagerRef = signer.storage.borrow<auth(FungibleToken.Withdraw, LockedTokens.RecoverLease) &LockedTokens.LockedTokenManager>(from: LockedTokens.LockedTokenManagerStoragePath)
            ?? panic("The signer does not store a LockedTokenManager object at the path "
                    .concat(LockedTokens.LockedTokenManagerStoragePath.toString()))

        let nodeRef = tokenManagerRef.borrowNodeForLease()
            ?? panic("Could not borrow a reference to a node in the LockedTokenManager of the signer's account")

        // Withdraw enough tokens to pay for fees, assuming there are some rewards in the rewards bucket
        tokenManagerRef.deposit(from: <-nodeRef.withdrawRewardedTokens(amount: 0.0001)!)

        // Withdraw tokens from the signer's stored vault
        self.sentVault <- nodeRef.withdrawUnstakedTokens(amount: amount)!
    }

    execute {

        // Get a reference to the recipient's Receiver
        let receiverRef =  getAccount(to)
            .capabilities.borrow<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            ?? panic("Could not borrow a Receiver reference to the FlowToken Vault in account "
                .concat(to.toString()).concat(" at path /public/flowTokenReceiver")
                .concat(". Make sure you are sending to an address that has ")
                .concat("a FlowToken Vault set up properly at the specified path."))

        // Deposit the withdrawn tokens in the recipient's receiver
        receiverRef.deposit(from: <-self.sentVault)
    }
}