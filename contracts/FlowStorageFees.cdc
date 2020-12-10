/*
 * The FlowStorageFees smart contract
 * Each account holds a `FlowStorageFees.StorageReservation` and a `FlowStorageFees.StorageReservationReceiver` on a predetermined path.
 * `FlowStorageFees.StorageReservation` holds the accounts Flow tokens that were reserved in order to increase its storage capacity.
 * An accounts storage capacity determines up to how much storage on chain it can use. An storage capacity is calculated by multiplying the amount of reserved flow with `StorageFee.storageBytesPerReservedFLOW`
 * The minimum amount of flow tokens reserved for storage capacity is `FlowStorageFees.minimumStorageReservation` this is paid during account creation, by the creator.
 * 
 * At the end of all transactions, any account that had any value changed in their storage has their storage capacity checked against their storage used and their reserved flow tokens against the minimum reservation.
 * If any account fails this check the transaction wil fail.
 * 
 * An account moving/deleting its `FlowStorageFees.StorageReservation` resource will result in the transaction failing because the account will have no storage capacity.
 * Moving the `FlowStorageFees.StorageReservationReceiver` will result in the account being unable to receive or withdraw reserved flow. This can be fixed by calling: 
 * ```
 * account.link<&FlowStorageFees.StorageReservation{FlowStorageFees.StorageReservationReceiver}>(
 *     FlowStorageFees.storageReservationStoragePath,
 *     target: FlowStorageFees.storageReservationReceiverPublicPath)
 * ```
 */
import FlowToken from 0xFLOWTOKENADDRESS

pub contract FlowStorageFees {
    // Emitted when storage capacity refunding is enabled.
    pub event RefundingEnabledChanged(_ refundingEnabled: Bool)
    
    // Emitted when the amount of storage capacity an account has per reserved Flow token changes
    pub event StorageBytesPerReservedFLOWChanged(_ storageBytesPerReservedFLOW: UFix64)

    // Emitted when the minimum amount of Flow tokens that an account needs to have reserved for storage capacity changes.
    pub event MinimumStorageReservationChanged(_ minimumStorageReservation: UFix64)

    // Emitted when the mount of Flow tokens reserved on an account, for storage capacity, changes.
    pub event StorageReservationChanged(address: Address, oldStorageReservation: UFix64, oldStorageCapacity: UInt64, newStorageReservation: UFix64, newStorageCapacity: UInt64)

    // Defines the path where each account should have a `StorageReservationReceiver` capability
    pub let storageReservationReceiverPublicPath: PublicPath

    // Defines the path where each account should have a `StorageReservation` capability
    pub let storageReservationStoragePath: StoragePath

    // Defines how much storage capacity every account has per reserved Flow token.
    // definition is written per unit of flow instead of the inverse, so there is no loss of precision calculating storage from flow, but there is loss of precision when calculating flow per storage.
    pub var storageBytesPerReservedFLOW: UFix64

    // Defines the minimum amount of Flow tokens that every account needs to have reserved for storage capacity.
    // If an account has less then this amount reserved by the end of any transaction it participated in, the transaction will fail.
    pub var minimumStorageReservation: UFix64

    // Enables or disables the refunding storage capacity.
    pub var refundingEnabled: Bool

    // An administrator resource that can change the parameters of the FlowStorageFees smart contract.
    pub resource Administrator {
        pub fun setRefundingEnabled(_ enabled: Bool) {
            if FlowStorageFees.refundingEnabled == enabled {
              return
            }
            FlowStorageFees.refundingEnabled = enabled
            emit RefundingEnabledChanged(enabled)
        }

        // Changes the amount storage capacity an account has per accounts' reserved storage.
        pub fun setStorageBytesPerReservedFLOW(_ storageBytesPerReservedFLOW: UFix64) {
            if FlowStorageFees.storageBytesPerReservedFLOW == storageBytesPerReservedFLOW {
              return
            }
            FlowStorageFees.storageBytesPerReservedFLOW = storageBytesPerReservedFLOW
            emit StorageBytesPerReservedFLOWChanged(storageBytesPerReservedFLOW)
        }

        // Changes the minimum amount of Flow tokens an account has to have reserved.
        pub fun setMinimumStorageReservation(_ minimumStorageReservation: UFix64) {
            if FlowStorageFees.minimumStorageReservation == minimumStorageReservation {
              return
            }
            FlowStorageFees.minimumStorageReservation = minimumStorageReservation
            emit MinimumStorageReservationChanged(minimumStorageReservation)
        }

        access(contract) init(){}
    }

    /* An interface for public access to accounts' storage reservation.
     * If `StorageReservationReceiver` capability is not on the accounts' `storageReservationReceiverPublicPath` path
     * the account won't be able to receive additional storage capacity or refund current storage capacity.
     */
    pub resource interface StorageReservationReceiver {
        pub fun deposit(from: @FlowToken.Vault) {
            pre {
                self.isInstance(Type<@StorageReservation>()): "The interface StorageReservationReceiver should only point to resource StorageReservation"
            }
        }

        access(contract) fun verifyStorageReservation(ownerAddress: Address, storageReservationId: UInt64): Bool {
            pre {
                self.isInstance(Type<@StorageReservation>()): "The interface StorageReservationReceiver should only point to resource StorageReservation"
            }
        }
    }

    // A counter to uniquely identify all `StorageReservation` resources.
    // This is needed to prevent an account refunding from a `StorageReservation` resources that is not on its own `storageReservationStoragePath` path.
    access(contract) var idCounter: UInt64

    /* The `StorageReservation` resource holds the amount of flow reserved for the accounts storage capacity. The amount of flow reserved in this resource determines the accounts storage capacity.
     * The `StorageReservation` resource should be on the accounts' `storageReservationStoragePath` path. It will be put there during `setupAccountStorage`.
     * The `StorageReservation` resource is not transferable or usable by a different accounts other than the one it was created for.
     * At the end of every transaction where any accounts' storage fields change its storage used is compared to the storage capacity calculated from the amount of flow reserved in this resource.
     */
    pub resource StorageReservation: StorageReservationReceiver {
        access(self) let ownerAddress: Address
        access(self) let storageReservationId: UInt64
        // The `vault` holds the flow tokens reserved for storage capacity on this account
        access(self) let reservedTokens: @FlowToken.Vault

        /* The `deposit` function allows any address to deposit additional flow tokens to this accounts storage reservation and thus adding to its storage capacity.
         * The function verifies that this 
         * A non 0 deposit triggers an `StorageReservationChanged` event.
         */
        pub fun deposit(from: @FlowToken.Vault){
            pre {
                self.verify(): "StorageReservation not on owners account or not on the correct path"
            }
            if from.balance == 0.0 {
                destroy from // it is empty so we can destroy it
                return
            }
            let oldStorageReservation = self.reservedTokens.balance
            
            self.reservedTokens.deposit(from: <- from)

            emit StorageReservationChanged(
                address: self.ownerAddress, 
                oldStorageReservation: oldStorageReservation, 
                oldStorageCapacity: FlowStorageFees.flowToStorageCapacity(oldStorageReservation), 
                newStorageReservation: self.reservedTokens.balance, 
                newStorageCapacity: FlowStorageFees.flowToStorageCapacity(self.reservedTokens.balance))
        }

        // The `withdraw` function allows the owner of this resource to withdraw flow tokens from it if the owner decides that he/she/it doesn't need as much storage capacity any more.
        pub fun withdraw(amount: UFix64): @FlowToken.Vault {
            pre {
                self.verify(): "StorageReservation not on owners account or not on the correct path"
                FlowStorageFees.refundingEnabled: "Refunding is currently disabled"
                self.reservedTokens.balance - amount >= FlowStorageFees.minimumStorageReservation:  "Cannot withdraw below the minimum storage reservation"
            }
            if amount == UFix64(0.0) {
                return <- (FlowToken.createEmptyVault() as! @FlowToken.Vault)
            }
            let oldStorageReservation = self.reservedTokens.balance
            
            let vault <- (self.reservedTokens.withdraw(amount: amount) as! @FlowToken.Vault)

            emit StorageReservationChanged(
                address: self.ownerAddress, 
                oldStorageReservation: oldStorageReservation, 
                oldStorageCapacity: FlowStorageFees.flowToStorageCapacity(oldStorageReservation), 
                newStorageReservation: self.reservedTokens.balance, 
                newStorageCapacity: FlowStorageFees.flowToStorageCapacity(self.reservedTokens.balance))

            return <- vault
        }

        /*
         * Verify itself, that it is on the expected account on the expected path and of the expected type.
         * In the verification procedure the `StorageReservation` tries to verify itself by calling its own method through its own receiver.
         * The steps of this procedure are as follows:
         * When depositing or withdrawing we assume that we are starting with a `StorageReservation` type that is actually from this contract.
         * We can assume this because whoever is starting that operation will need to cast the type, and the type casting will fail if it is an impostor type.
         * 1. The verification procedure is started with calling `StorageReservation.verify`
         * 2. This tries to get the `StorageReservationReceiver` from this `StorageReservation`s `ownerAccount` (which may or may not be the holder of this resource)
         *   - if this fails the method will panic. This can happen if:
         *       i. `StorageReservationReceiver` is not set up properly on `ownerAccount`. 
         *       ii. `StorageReservationReceiver` on `ownerAccount` is an impostor type. 
         * 3. Then this calls `StorageReservationReceiver.verifyStorageReservation(ownerAddress: self.ownerAddress, storageReservationId: self.storageReservationId)`
         *   - this will panic if:
         *       i. `StorageReservationReceiver`s underlying `StorageReservation` on `ownerAccount` is an impostor type.
         *   - this will return false if:
         *       i. `StorageReservation` on `ownerAccount` does not have the same `ownerAccount` (this means that this `StorageReservation` is not on its `ownerAccount` or not on the correct path)
         *       ii. `StorageReservation` on `ownerAccount` does not have the same `storageReservationId` (which is unique for each `StorageReservation`) (this means that the `StorageReservation` is not on the correct path, because a different `StorageReservation` is on that path)
         * 4. We can now assume that the `StorageReservation` on `ownerAccount` is actually this `StorageReservation`
         */
        access(self) fun verify(): Bool {
            let receiver = FlowStorageFees.getStorageReservationReceiver(self.ownerAddress)
            return receiver.verifyStorageReservation(ownerAddress: self.ownerAddress, storageReservationId: self.storageReservationId)
        }

        // This is called from the method above. The StorageReservation on this location should be the one that is expected.
        access(contract) fun verifyStorageReservation(ownerAddress: Address, storageReservationId: UInt64): Bool {
            if self.ownerAddress != ownerAddress || self.storageReservationId != storageReservationId  {
                return false
            }
            return true
        }

        // Initialize the StorageCapacity with the vault provided.
        access(contract) init(ownerAddress: Address, reservedTokens: @FlowToken.Vault) {
            self.storageReservationId = FlowStorageFees.idCounter
            FlowStorageFees.idCounter = FlowStorageFees.idCounter + UInt64(1)

            self.ownerAddress = ownerAddress
            self.reservedTokens <- reservedTokens

            emit StorageReservationChanged(
                address: self.ownerAddress, 
                oldStorageReservation: 0.0, 
                oldStorageCapacity: 0, 
                newStorageReservation: self.reservedTokens.balance, 
                newStorageCapacity: FlowStorageFees.flowToStorageCapacity(self.reservedTokens.balance))
        }

        destroy() {
            // The transaction will be reverted because the account this resource was on doesn't have any capacity any more.
            destroy self.reservedTokens
        }
    }

    /* This function is called during account creation to setup the account:
     * - Creates a new `StorageReservation` resource.
     * - Puts this resource in the accounts storage.
     * - Puts a public capability in the accounts public storage.
     * If the function is called on an existing account with `StorageReservation` on the account it will fail.
     * The `storageReservation` should contain at least `FlowStorageFees.minimumStorageReservation`
     */
    pub fun setupAccountStorage(account: AuthAccount, storageReservation: @FlowToken.Vault){
        pre{
            storageReservation.balance >= FlowStorageFees.minimumStorageReservation: "Initial storage reservation should be at least the minimum storage reservation (FlowStorageFees.minimumStorageReservation)"
            !account.getCapability<&StorageReservation{StorageReservationReceiver}>(self.storageReservationReceiverPublicPath)!.check(): "Account already has storage setup."
        }

        let storageCapacity <- create StorageReservation(
            ownerAddress: account.address,
            reservedTokens: <- storageReservation)

        account.save(<- storageCapacity, to: self.storageReservationStoragePath)

        account.link<&StorageReservation{StorageReservationReceiver}>(
            self.storageReservationReceiverPublicPath,
            target: self.storageReservationStoragePath
        )
    }

    // This function gets a reference to a `StorageReservationReceiver` from a address
    pub fun getStorageReservationReceiver(_ address: Address): &StorageReservation{StorageReservationReceiver} {
        return getAccount(address).getCapability<&StorageReservation{StorageReservationReceiver}>(self.storageReservationReceiverPublicPath)!.borrow()
            ?? panic("Could not borrow a reference to the StorageReservationReceiver")
    }

    pub fun flowToStorageCapacity(_ amount: UFix64): UInt64 {
        return UInt64(amount * FlowStorageFees.storageBytesPerReservedFLOW)
    }

    pub fun storageCapacityToFlow(_ amount: UInt64): UFix64 {
        // loss of precision
        // putting the result back into `flowToStorageCapacity` possibly won't yield the same result
        return UFix64(amount) / FlowStorageFees.storageBytesPerReservedFLOW
    }

    init(adminAccount: AuthAccount) {
        self.storageReservationReceiverPublicPath = /public/flowStorageReservation
        self.storageReservationStoragePath = /storage/flowStorageReservation
        self.storageBytesPerReservedFLOW = 1000000.0 // 1 Mb per 1 Flow token
        self.minimumStorageReservation = 0.0 // for testing otherwise -> // 0.1 // or 100 kb of storage capacity
        self.refundingEnabled = false
        self.idCounter = 0

        let admin <- create Administrator()
        adminAccount.save(<-admin, to: /storage/storageFeesAdmin)
    }
}