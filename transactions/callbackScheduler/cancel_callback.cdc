import "FlowCallbackScheduler"
import "FlowCallbackUtils"
import "TestFlowCallbackHandler"
import "FlowToken"
import "FungibleToken"

transaction(id: UInt64) {

    prepare(account: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability, GetStorageCapabilityController) &Account) {

        let manager = account.storage.borrow<auth(FlowCallbackUtils.Owner) &FlowCallbackUtils.CallbackManager>(from: FlowCallbackUtils.managerStoragePath)
            ?? panic("Could not borrow a CallbackManager reference from \(FlowCallbackUtils.managerStoragePath)")

        let vault = account.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow FlowToken vault")

        vault.deposit(from: <-manager.cancel(id: id))
    }
} 
