import FlowToken from "./FlowToken.cdc"

pub contract StorageFees {

    // Defines the minimum unit (chunk) size of storage in bytes. Storage can only be bought (or refunded) in a multiple of the minimum storage unit.
    pub var minimumStorageUnit: UInt64

    // Defines the minimum amount of `storage_capacity` an address can have and also the amount every new account has. `minimumAccountStorage` is a multiple of `minimumStorageUnit`.
    pub var minimumAccountStorage: UInt64

    // Defines the cost of 1 byte of storage in FLOW tokens.
    pub var flowPerByte: UFix64

    // Defines the cost of purchasing the initial minimum storage in FLOW tokens.
    pub var flowPerAccountCreation: UFix64

    // Defines the cost of 1 byte of storage in FLOW tokens.
    pub var refundingEnabled: Bool

    access(contract) var idCounter: UInt64

    pub resource Administrator {
        pub fun setRefundingEnabled(enabled: Bool) {
            StorageFees.refundingEnabled = enabled
        }

        pub fun setMinimumAccountStorage(minimumAccountStorage: UInt64) {
            pre{
                minimumAccountStorage % StorageFees.minimumStorageUnit == UInt64(0): "Minimum account storage must be a multiple of the minimum storage unit"
            }
            StorageFees.minimumAccountStorage = minimumAccountStorage
        }

        pub fun setFlowPerByte(flowPerByte: UFix64) {
            StorageFees.flowPerByte = flowPerByte
        }

        pub fun setFlowPerAccountCreation(flowPerAccountCreation: UFix64) {
            StorageFees.flowPerAccountCreation = flowPerAccountCreation
        }
    }

    pub resource interface StorageCapacityCapability{
        access(contract) var id: UInt64
        pub var storageCapacity: UInt64
        access(contract) let address: Address
        access(contract) fun addStorageCapacity(address: Address, amount: UInt64, paymentVault: @FlowToken.Vault)
    }

    pub struct StorageCapacityPurchase{
        pub let storageCapacity: UInt64
        pub let flowCost: UFix64

        init(storageCapacity: UInt64, flowCost: UFix64) {
            self.storageCapacity = storageCapacity
            self.flowCost = flowCost
        }
    }

    pub resource StorageCapacity: StorageCapacityCapability {
        access(contract) var id: UInt64
        pub var storageCapacity: UInt64
        access(contract) let address: Address
        access(self) let vault: @FlowToken.Vault
        access(self) let purchases: [StorageCapacityPurchase]

        access(contract) fun addStorageCapacity(address: Address, amount: UInt64, paymentVault: @FlowToken.Vault){
            pre{
                self.address == address: "Unexpected address on storage capacity"
            }
            self.purchases.append(StorageCapacityPurchase(storageCapacity: amount, flowCost: paymentVault.balance))
            self.storageCapacity = self.storageCapacity + amount
            self.vault.deposit(<- paymentVault)
        }

        access(contract) fun refundStorageCapacity(storageAmount: UInt64): @FlowToken.Vault{
            self.storageCapacity = self.storageCapacity - storageAmount

            var flowAmount = 0.0
            var storageCapacity = storageAmount
            var i = self.purchases.length
            while i > 0 && storageCapacity > UInt64(0){
                i = i - 1
                let purchase = self.purchases.removeLast()
                if purchase.storageCapacity <= storageCapacity{
                    storageCapacity = storageCapacity - purchase.storageCapacity
                    flowAmount = flowAmount + purchase.flowCost
                } else {
                    let relativeFlow = purchase.flowCost * UFix64(storageCapacity)/ UFix64(purchase.storageCapacity)
                    flowAmount = flowAmount + relativeFlow
                    storageCapacity = 0
                    self.purchases.append(StorageCapacityPurchase(storageCapacity:purchase.storageCapacity- storageCapacity,  flowCost: purchase.flowCost - relativeFlow))
                    break;
                }
            }

            if storageCapacity != UInt64(0) {
                panic("Cannot refund storage")
            }

            return <- self.vault.withdraw(flowAmount)
        }

        init(storageCapacity: UInt64, address: Address, vault: @FlowToken.Vault) {
            self.id = StorageFees.idCounter
            StorageFees.idCounter = StorageFees.idCounter + UInt64(1)
            self.storageCapacity = storageCapacity
            self.address = address
            self.purchases = [ StorageCapacityPurchase(storageCapacity: storageCapacity, flowCost: vault.balance)]
            self.vault <- vault
        }

        destroy() {
            // in general the transaction will be reverted because the account doesnt have any capacity anymore
            destroy self.vault
        }
    }

    pub fun setupStorageForAccount(paymentVault: @FlowToken.Vault, authAccount: AuthAccount){
        pre{
            paymentVault.balance != StorageCapacity.flowPerAccountCreation: "Account creation cost exactly ".concat(StorageCapacity.flowPerAccountCreation).concat(" Flow tokens.")
            authAccount.check<&StorageCapacity{StorageCapacityCapability}>(/public/storageCapacity): "Account already has storage setup"
        }
        let storageCapacity <- create StorageCapacity(
            storageCapacity: StorageCapacity.minimumAccountStorage,
            address: authAccount.address,
            vault: <- paymentVault)

        authAccount.save(<- storageCapacity, to: /storage/storageCapacity)

        authAccount.link<&StorageCapacity{StorageCapacityCapability}>(
            /public/storageCapacity,
            target: /storage/storageCapacity
        )
    }

    pub fun addStorageCapacity(to: Address, amount: UInt64, paymentVault: @FlowToken.Vault){
        pre{
            amount % StorageFees.minimumStorageUnit == UInt64(0): "Amount of storage capacity to add must be a multiple of the minimum storage unit"
            paymentVault.balance != StorageFees.flowPerByte * UFix64(amount): "Adding ".concat(amount.toString()).concat(" storage capacity cost exactly ").concat(StorageCapacity.flowPerByte*amount).concat(" Flow tokens.")
            
        }
        let storageCapacityCapability = getAccount(to).getCapability<&StorageCapacity{StorageCapacityCapability}>(/public/storageCapacity)!.borrow()
        if storageCapacityCapability == nil {
            panic("Account needs to be setup first")
        }

        storageCapacityCapability?.addStorageCapacity(address: to, amount: amount, paymentVault: paymentVault)
    }

    pub fun refundStorageCapacity(from: Address, storageCapacityReference: &StorageCapacity, storageAmount: UInt64): @FlowToken.Vault {
        pre{
            storageAmount % StorageFees.minimumStorageUnit == UInt64(0): "Amount of storage capacity to add must be a multiple of the minimum storage unit"
            storageCapacityReference.storageCapacity - storageAmount   > StorageFees.minimumAccountStorage:"Cannot decrease accounts storage below the minimum"
            StorageFees.refundingEnabled: "Refunding storage is disabled"
        }
        let storageCapacityCapability = getAccount(from).getCapability<&StorageCapacity{StorageCapacityCapability}>(/public/storageCapacity)!.borrow()
        if storageCapacityCapability == nil {
            panic("Account needs to be setup first")
        }

        if storageCapacityCapability?.address != storageCapacityReference.address || storageCapacityCapability?.id != storageCapacityReference.id {
            panic("Cannot refund storage from this storage capacity")
        }

        return <- storageCapacityReference.refundStorageCapacity(storageAmount: storageAmount)
    }

    init(adminAccount: AuthAccount) {
        self.minimumStorageUnit = 10000 // 10kb
        self.minimumAccountStorage = 100000 //100kb
        self.flowPerByte = 0.000001 // 1kB for 1mF
        self.flowPerAccountCreation = 0.1
        self.refundingEnabled = false
        self.idCounter = 0

        let admin <- create Administrator()
        adminAccount.save(<-admin, to: /storage/flowTokenAdmin)
    }
}