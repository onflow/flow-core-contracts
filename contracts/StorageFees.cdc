import FlowToken from 0xFLOWTOKENADDRESS

pub contract StorageFees {
    // Emitted when storage capacity refunding is enabled or disabled.
    pub event RefundingEnabledChanged(_ enabled: Bool)
    // Emitted when the minimum account storage capacity changes.
    pub event MinimumAccountStorageChanged(_ minimumAccountStorage: UInt64)
    // Emitted when the price of storage capacity changes.
    pub event FlowPerByteChanged(_ flowPerByte: UFix64)
    // Emitted when the flow cost of buying initial storage on a account changes.
    pub event FlowPerAccountCreationChanged(_ flowPerAccountCreation: UFix64)
    // Emitted when more storage capacity is added to an account.
    pub event StorageCapacityAdded(address: Address, added: UInt64, newStorageCapacity: UInt64)
    // Emitted when a new account is given minimum storage capacity.
    pub event StorageCapacityCreated(address: Address, newStorageCapacity: UInt64)
    // Emitted when an account refunds its storage.
    pub event StorageCapacityRefunded(address: Address, refunded: UInt64, newStorageCapacity: UInt64)

    // Defines the minimum unit (chunk) size of storage in bytes. Storage can only be bought (or refunded) in a multiple of the minimum storage unit.
    pub let minimumStorageUnit: UInt64

    // Defines the minimum amount of storage capacity an address can have and also the amount every new account has. `minimumAccountStorage` is a multiple of `minimumStorageUnit`.
    pub var minimumAccountStorage: UInt64

    // Defines the cost in FLOW tokens of 1 byte of storage.
    pub var flowPerByte: UFix64

    // Defines the cost in FLOW tokens of purchasing the initial minimum storage.
    pub var flowPerAccountCreation: UFix64

    // Enables or disables the refunding storage capacity.
    pub var refundingEnabled: Bool

    // An administrator resource that can change the parameters of the StorageFees smart contract.
    pub resource Administrator {
        pub fun setRefundingEnabled(_ enabled: Bool) {
            if StorageFees.refundingEnabled == enabled {
              return
            }
            StorageFees.refundingEnabled = enabled
            emit RefundingEnabledChanged(enabled)
        }

        // Changes the minimum account storage.
        // Checks if the new minimum is a multiple of minimum storage unit.
        pub fun setMinimumAccountStorage(_ minimumAccountStorage: UInt64) {
            pre {
                minimumAccountStorage % StorageFees.minimumStorageUnit == UInt64(0): "Minimum account storage must be a multiple of the minimum storage unit"
            }
            if StorageFees.minimumAccountStorage == minimumAccountStorage {
              return
            }
            StorageFees.minimumAccountStorage = minimumAccountStorage
            emit MinimumAccountStorageChanged(minimumAccountStorage)
        }

        // Changes the cost in FLOW tokens of purchasing additional storage capacity.
        pub fun setFlowPerByte(_ flowPerByte: UFix64) {
            if StorageFees.flowPerByte == flowPerByte {
              return
            }
            StorageFees.flowPerByte = flowPerByte
            emit FlowPerByteChanged(flowPerByte)
        }

        // Changes the cost in FLOW tokens of storage for newly created accounts.
        pub fun setFlowPerAccountCreation(_ flowPerAccountCreation: UFix64) {
            if StorageFees.flowPerAccountCreation == flowPerAccountCreation {
              return
            }
            StorageFees.flowPerAccountCreation = flowPerAccountCreation
            emit FlowPerAccountCreationChanged(flowPerAccountCreation)
        }

        access(contract) init(){}
    }

    // An internal type to store the past purchases of storage capacity for the purpose of refunding the same amount of Flow tokens as was used to purchase it.
    pub struct StorageCapacityPurchase {
        pub let storageCapacity: UInt64
        pub let flowCost: UFix64

        access(contract) init(storageCapacity: UInt64, flowCost: UFix64) {
            self.storageCapacity = storageCapacity
            self.flowCost = flowCost
        }
    }
    
    // An interface for public access to accounts' storage.
    // If `StorageCapacityAccess` capability is not on the accounts' `/public/storageCapacity` path 
    // the account won't be able to receive additional storage capacity or refund current storage capacity.
    pub resource interface StorageCapacityAccess {
        // The amount of storage capacity available to the address holding the StorageCapacity resource.
        pub var storageCapacity: UInt64

        access(contract) let address: Address
        access(contract) var storageCapacityId: UInt64
        access(contract) fun addStorageCapacity(address: Address, storageAmount: UInt64, payment: @FlowToken.Vault)
    }

    // A counter to uniquely identify all `StorageCapacity` resources.
    // This is needed to prevent an account refunding from a `StorageCapacity` resources that is not on its `/storage/storageCapacity` path.
    access(contract) var idCounter: UInt64

    // The `StorageCapacity` resource holds the amount of storage capacity available to the account that has this resource in its storage.
    // The `StorageCapacity` resource should be on the accounts' `/storage/storageCapacity` path. It will be put there during `setupStorageForAccount`.
    // The `StorageCapacity` resource should not be transferable or usable by a different account than the one it was created for.
    // At the end of every transaction where an accounts' storage used is changed its storage used is compared to the storageCapacity on this resource.
    pub resource StorageCapacity: StorageCapacityAccess {
        // The amount of storage capacity available to the address holding the StorageCapacity resource.
        pub var storageCapacity: UInt64

        // The `address` field exists to prevent swapping StorageCapacity resource between accounts.
        access(contract) let address: Address
        // The `storageCapacityId` field exists to prevent refunding a StorageCapacity resource that the account in not currently using (the resource is on accounts' `/storage/storageCapacity` path).
        access(contract) var storageCapacityId: UInt64
        // The `vault` hold all the payments made for this storage capacity.
        access(self) let vault: @FlowToken.Vault
        // `purchases` are the history of the amount of storage bought and the amount of Flow tokens it was bought for. This is to enable refunding the exact amount that was used to purchase the storage in the first place.
        access(self) let purchases: [StorageCapacityPurchase]

        // The `addStorageCapacity` function is called by the `StorageFees` contract to add additional storage capacity to this `StorageCapacity` resource.
        // The address on the `StorageCapacity` resource is checked against the address that `StorageFees` contract expects to see when adding storage for a specific account.
        // The calling function in StorageFees contract checks that storageAmount is a valid value and that the payment is sufficient.
        // Storage capacity is incremented, the payment is deposited into the existing vault and an event is triggered.
        access(contract) fun addStorageCapacity(address: Address, storageAmount: UInt64, payment: @FlowToken.Vault){
            pre{
                self.address == address: "Unexpected address on storage capacity"
            }

            self.purchases.append(StorageCapacityPurchase(storageCapacity: storageAmount, flowCost: payment.balance))
            self.storageCapacity = self.storageCapacity + storageAmount
            self.vault.deposit(from: <- payment)

            emit StorageCapacityAdded(address: address, added: storageAmount, newStorageCapacity: self.storageCapacity)
        }

        // The `refundStorageCapacity` function is called by the `StorageFees` contract to refund storage capacity from this `StorageCapacity` resource.
        // The calling function in `StorageFees` contract checks that:
        // - `storageAmount` is a valid value.
        // - The account would not be below minimum storage capacity.
        // - `StorageCapacity` resource is on the correct account and in the correct place in storage.
        // The amount of Flow tokens returned is the exact amount (besides rounding errors) that was paid to purchase this storage capacity.
        // If at the end of this transaction the account is over capacity the transaction will be reverted, so we do not need to worry about that here.
        // This function triggers a refund event
        access(contract) fun refundStorageCapacity(storageAmount: UInt64): @FlowToken.Vault{
            self.storageCapacity = self.storageCapacity - storageAmount

            var refundedFlowAmount = 0.0
            var storageToRefund = storageAmount

            var i = self.purchases.length
            while i > 0 && storageToRefund > UInt64(0){
                i = i - 1
                let purchase = self.purchases.removeLast()
                if purchase.storageCapacity <= storageToRefund { // refund this entire purchase
                    
                    storageToRefund = storageToRefund - purchase.storageCapacity
                    refundedFlowAmount = refundedFlowAmount + purchase.flowCost
                } else { // refund this purchase partially
                    // possible rounding errors, but the error is not cumulative. You might receive slightly less or more flow back, but the remaining flow will add up to the correct number. 
                    let relativeFlow = purchase.flowCost * UFix64(storageToRefund)/ UFix64(purchase.storageCapacity) 
                    refundedFlowAmount = refundedFlowAmount + relativeFlow
                    self.purchases.append(StorageCapacityPurchase(storageCapacity:purchase.storageCapacity - storageToRefund,  flowCost: purchase.flowCost - relativeFlow))
                    storageToRefund = 0
                    break;
                }
            }

            if storageToRefund != UInt64(0) {
                // could only happen due to an implementation error
                panic("Cannot refund storage")
            }

            emit StorageCapacityRefunded(address: self.address, refunded: storageAmount, newStorageCapacity: self.storageCapacity)
            return <- (self.vault.withdraw(amount: refundedFlowAmount) as! @FlowToken.Vault)
        }

        // Initialize the StorageCapacity to the minimum account storage with the vault provided.
        access(contract) init(storageCapacity: UInt64, address: Address, vault: @FlowToken.Vault) {
            self.storageCapacityId = StorageFees.idCounter
            StorageFees.idCounter = StorageFees.idCounter + UInt64(1)

            self.storageCapacity = storageCapacity
            self.address = address
            self.purchases = [StorageCapacityPurchase(storageCapacity: storageCapacity, flowCost: vault.balance)]
            self.vault <- vault

            emit StorageCapacityCreated(address: self.address, newStorageCapacity: self.storageCapacity)
        }

        destroy() {
            // The transaction will be reverted because the account this resource was on doesn't have any capacity any more.
            destroy self.vault
        }
    }

    // This function is called during account creation to setup the account:
    // - Creates a new `StorageCapacity` resource.
    // - Puts this resource in the accounts storage.
    // - Puts a public capability in the accounts public storage.
    // If the function is called on an existing account with `StorageCapacity` it will fail.
    // The paymentVault should contain the exact amount of Flow tokens needed to purchase minimum storage for an account (`StorageFees.flowPerAccountCreation`)
    pub fun setupStorageForAccount(paymentVault: @FlowToken.Vault, authAccount: AuthAccount){
        pre{
            paymentVault.balance == StorageFees.flowPerAccountCreation:
                "Account creation cost exactly ".concat(StorageFees.flowPerAccountCreation.toString()).concat(" Flow tokens.")
            authAccount.getCapability<&StorageCapacity{StorageCapacityAccess}>(/public/storageCapacity)!.check():
                "Account already has storage setup."
        }

        let storageCapacity <- create StorageCapacity(
            storageCapacity: StorageFees.minimumAccountStorage,
            address: authAccount.address,
            vault: <- paymentVault)

        authAccount.save(<- storageCapacity, to: /storage/storageCapacity)

        authAccount.link<&StorageCapacity{StorageCapacityAccess}>(
            /public/storageCapacity,
            target: /storage/storageCapacity
        )
    }

    // Call this function to purchase additional storage for an account.
    // The paymentVault balance must match the cost for storageAmount worth of storage capacity (see `getFlowCost` function).
    // storageAmount needs to be a multiple of StorageFees.minimumStorageUnit (see `roundUpStorageCapacity`).
    // A check is made that the `StorageCapacity` resource the account is currently holding, is actually for that account.
    // After validation internally calls `StorageCapacity.addStorageCapacity`.
    // See `purchaseMinimumAditionalRequiredStorageCapacity` for a convenient way to keep an accounts' capacity over storage used.
    pub fun addStorageCapacity(to: Address, storageAmount: UInt64, paymentVault: @FlowToken.Vault){
        pre{
            storageAmount % StorageFees.minimumStorageUnit == UInt64(0):
                "Amount of storage capacity to add must be a multiple of the minimum storage unit"
            paymentVault.balance != StorageFees.getFlowCost(storageAmount):
                "Adding ".concat(storageAmount.toString()).concat(" storage capacity cost exactly ").concat((StorageFees.getFlowCost(storageAmount)).toString()).concat(" Flow tokens.")
            
        }
        let storageCapacityCapability = getAccount(to).getCapability<&StorageCapacity{StorageCapacityAccess}>(/public/storageCapacity)!.borrow()
        if storageCapacityCapability == nil {
            panic("Account needs to be setup first")
            // account setup should already have happened at account creation
            // most likely the user moved his/hers `StorageCapacity` resource or the public `StorageCapacityAccess` capability
        }

        storageCapacityCapability!.addStorageCapacity(address: to, storageAmount: storageAmount, payment: <- paymentVault)
    }

    // Call this method to refund some storage capacity from the StorageCapacity resource you are currently holding.
    // This should not put the account under `StorageFees.minimumAccountStorage`.
    // Refunding needs to be enabled.
    // storageAmount needs to be a multiple of `StorageFees.minimumStorageUnit` (see `roundUpStorageCapacity`).
    // After validation internally calls StorageCapacity.refundStorageCapacity.
    pub fun refundStorageCapacity(storageCapacityReference: &StorageCapacity, storageAmount: UInt64): @FlowToken.Vault {
        pre{
            storageAmount % StorageFees.minimumStorageUnit == UInt64(0):
                "Amount of storage capacity to add must be a multiple of the minimum storage unit"
            storageCapacityReference.storageCapacity - storageAmount > StorageFees.minimumAccountStorage:
                "Cannot decrease accounts storage below the minimum"
            StorageFees.refundingEnabled:
                "Refunding storage is disabled"
        }
        let storageCapacityCapability = getAccount(storageCapacityReference.address).getCapability<&StorageCapacity{StorageCapacityAccess}>(/public/storageCapacity)!.borrow()
        if storageCapacityCapability == nil {
            panic("Account needs to be setup first")
        }

        if storageCapacityCapability!.storageCapacityId != storageCapacityReference.storageCapacityId {
            panic("Cannot refund storage from this storage capacity")
        }

        return <- storageCapacityReference.refundStorageCapacity(storageAmount: storageAmount)
    }

    // Call this function to get the smallest multiple of `StorageFees.minimumStorageUnit` that is large (or equal to) storageAmount.
    // e.g.: round up storageAmount.
    pub fun roundUpStorageCapacity(_ storageAmount: UInt64): UInt64 {
        if storageAmount % StorageFees.minimumStorageUnit == UInt64(0){
            return storageAmount
        }
        return (storageAmount / StorageFees.minimumStorageUnit + UInt64(1)) * StorageFees.minimumStorageUnit
    }
    // Call this function to get the largest multiple of `StorageFees.minimumStorageUnit` that is smaller (or equal to) storageAmount.
    // e.g.: round up storageAmount.
    pub fun roundDownStorageCapacity(_ storageAmount: UInt64): UInt64 {
        if storageAmount % StorageFees.minimumStorageUnit == UInt64(0){
            return storageAmount
        }
        return (storageAmount / StorageFees.minimumStorageUnit) * StorageFees.minimumStorageUnit
    }


    // Call this function to get the minimum amount of additional storage capacity an account needs in order for the transaction to pass.
    // The result will be a multiple of `StorageFees.minimumStorageUnit`.
    pub fun getMinimumAditionalRequiredStorageCapacity(_ address: Address): UInt64 {
        if address.storageUsed <= address.storageCapacity {
            return UInt64(0)
        }
        return StorageFees.roundUpStorageCapacity(address.storageUsed - address.storageCapacity)
    }

    // Call this function to get the cost of purchasing storageAmount of additional storage capacity in Flow tokens.
    pub fun getFlowCost(_ storageAmount: UInt64): UFix64 {
        return UFix64(storageAmount) * self.flowPerByte
    }


    // This is a convenience function to purchase the minimum amount of additional storage capacity an account needs in order for the transaction to pass.
    // The payment vault should contain at least `getFlowCost(getMinimumAditionalRequiredStorageCapacity(address))` Flow tokens.
    // The vault that is returned will contain the remainder of Flow tokens.
    pub fun purchaseMinimumAditionalRequiredStorageCapacity(for: Address, paymentVault: @FlowToken.Vault): @FlowToken.Vault {
        let storageAmount = StorageFees.getMinimumAditionalRequiredStorageCapacity(for)
        let payment <- paymentVault.withdraw(amount: StorageFees.getFlowCost(storageAmount)) as! @FlowToken.Vault
        StorageFees.addStorageCapacity(to: for, storageAmount: storageAmount, paymentVault: <- payment)
        return <- paymentVault
    }

    init(adminAccount: AuthAccount) {
        self.minimumStorageUnit = 10000 // 10kb
        self.minimumAccountStorage = 100000 //100kb
        self.flowPerByte = 0.000001 // 1kB for 1mF
        self.flowPerAccountCreation = 0.1
        self.refundingEnabled = false
        self.idCounter = 0

        let admin <- create Administrator()
        adminAccount.save(<-admin, to: /storage/storageFeesAdmin)
    }
}