import "FlowTransactionScheduler"
import "FlowTransactionSchedulerUtils"
import "FlowToken"
import "FungibleToken"
import "EVM"

transaction(
    timestamp: UFix64,
    feeAmount: UFix64,
    effort: UInt64,
    priority: UInt8,
    coaTXTypeEnum: UInt8,
    revertOnFailure: Bool,
    amount: UFix64?,
    callToEVMAddress: String?,
    data: [UInt8]?,
    gasLimit: UInt64?,
    value: UInt?
) {

    prepare(account: auth(BorrowValue, SaveValue, IssueStorageCapabilityController, PublishCapability, GetStorageCapabilityController) &Account) {

        // if a transaction scheduler manager has not been created for this account yet, create one
        if !account.storage.check<@{FlowTransactionSchedulerUtils.Manager}>(from: FlowTransactionSchedulerUtils.managerStoragePath) {
            let manager <- FlowTransactionSchedulerUtils.createManager()
            account.storage.save(<-manager, to: FlowTransactionSchedulerUtils.managerStoragePath)

            // create a public capability to the callback manager
            let managerRef = account.capabilities.storage.issue<&{FlowTransactionSchedulerUtils.Manager}>(FlowTransactionSchedulerUtils.managerStoragePath)
            account.capabilities.publish(managerRef, at: FlowTransactionSchedulerUtils.managerPublicPath)
        }
        
        // If a COA transaction handler has not been created for this account yet, create one,
        // store it, and issue a capability that will be used to create the transaction
        if !account.storage.check<@FlowTransactionSchedulerUtils.COATransactionHandler>(from: FlowTransactionSchedulerUtils.coaHandlerStoragePath()) {

            var coaCapability: Capability<auth(EVM.Owner) &EVM.CadenceOwnedAccount>? = nil

            // get the COA capability
            for controller in account.capabilities.storage.getControllers(forPath: /storage/evm) {
                if let capability = controller.capability as? Capability<auth(EVM.Owner) &EVM.CadenceOwnedAccount> {
                    coaCapability = capability
                    break
                }
            }
            if coaCapability == nil {
                coaCapability = account.capabilities.storage.issue<auth(EVM.Owner) &EVM.CadenceOwnedAccount>(/storage/evm)
            }

            var flowTokenVaultCapability: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>? = nil

            // get the FlowToken Vault capability
            if let newFlowTokenVaultCapability = account.capabilities.storage
                            .getControllers(forPath: /storage/flowTokenVault)[0]
                            .capability as? Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault> {
                flowTokenVaultCapability = newFlowTokenVaultCapability
            } else {
                flowTokenVaultCapability = account.capabilities.storage.issue<auth(FungibleToken.Withdraw) &FlowToken.Vault>(/storage/flowTokenVault)
            }

            let handler <- FlowTransactionSchedulerUtils.createCOATransactionHandler(
                coaCapability: coaCapability!,
                flowTokenVaultCapability: flowTokenVaultCapability!
            )
        
            account.storage.save(<-handler, to: FlowTransactionSchedulerUtils.coaHandlerStoragePath())
            account.capabilities.storage.issue<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>(FlowTransactionSchedulerUtils.coaHandlerStoragePath())
            
            let publicHandlerCap = account.capabilities.storage.issue<&{FlowTransactionScheduler.TransactionHandler}>(FlowTransactionSchedulerUtils.coaHandlerStoragePath())
            account.capabilities.publish(publicHandlerCap, at: FlowTransactionSchedulerUtils.coaHandlerPublicPath())
        }

        // Get the entitled capability that will be used to create the transaction
        // Need to check both controllers because the order of controllers is not guaranteed
        var handlerCap: Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>? = nil
        
        if let cap = account.capabilities.storage
                            .getControllers(forPath: FlowTransactionSchedulerUtils.coaHandlerStoragePath())[0]
                            .capability as? Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}> {
            handlerCap = cap
        } else {
            handlerCap = account.capabilities.storage
                            .getControllers(forPath: FlowTransactionSchedulerUtils.coaHandlerStoragePath())[1]
                            .capability as! Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>
        }
        
        // borrow a reference to the vault that will be used for fees
        let vault = account.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow FlowToken vault")
        
        let fees <- vault.withdraw(amount: feeAmount) as! @FlowToken.Vault
        let priorityEnum = FlowTransactionScheduler.Priority(rawValue: priority)
            ?? FlowTransactionScheduler.Priority.High

        // borrow a reference to the callback manager
        let manager = account.storage.borrow<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>(from: FlowTransactionSchedulerUtils.managerStoragePath)
            ?? panic("Could not borrow a Manager reference from \(FlowTransactionSchedulerUtils.managerStoragePath)")


        let coaHandlerParams = FlowTransactionSchedulerUtils.COAHandlerParams(
            txType: coaTXTypeEnum,
            revertOnFailure: revertOnFailure,
            amount: amount,
            callToEVMAddress: callToEVMAddress,
            data: data,
            gasLimit: gasLimit,
            value: value
        )

        let coaHandlerParamsArray = [coaHandlerParams]
        
        // Schedule the COA transaction with the main contract
        manager.schedule(
            handlerCap: handlerCap!,
            data: coaHandlerParamsArray,
            timestamp: timestamp,
            priority: priorityEnum,
            executionEffort: effort,
            fees: <-fees
        )
    }
} 
