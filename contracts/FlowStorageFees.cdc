/*
 * The FlowStorageFees smart contract
 *
 * An account's storage capacity determines up to how much storage on chain it can use. An storage capacity is calculated by multiplying the amount of reserved flow with `StorageFee.storageBytesPerReservedFLOW`
 * The minimum amount of flow tokens reserved for storage capacity is `FlowStorageFees.minimumStorageReservation` this is paid during account creation, by the creator.
 * 
 * At the end of all transactions, any account that had any value changed in their storage 
 * has their storage capacity checked against their storage used and their main flow token vault against the minimum reservation.
 * If any account fails this check the transaction wil fail.
 * 
 * An account moving/deleting its `FlowToken.Vault` resource will result 
 * in the transaction failing because the account will have no storage capacity.
 * 
 * This contract does not have to import `FlowToken` because it only tracks the
 * storage fee parameters. The execution environment checks the `FlowToken.Vault` balance.
 *
 */

pub contract FlowStorageFees {

    // Emitted when the amount of storage capacity an account has per reserved Flow token changes
    pub event StorageBytesPerReservedFLOWChanged(_ storageBytesPerReservedFLOW: UFix64)

    // Emitted when the minimum amount of Flow tokens that an account needs to have reserved for storage capacity changes.
    pub event MinimumStorageReservationChanged(_ minimumStorageReservation: UFix64)

    // Defines how much storage capacity every account has per reserved Flow token.
    // definition is written per unit of flow instead of the inverse, so there is no loss of precision calculating storage from flow, but there is loss of precision when calculating flow per storage.
    pub var storageBytesPerReservedFLOW: UFix64

    // Defines the minimum amount of Flow tokens that every account needs to have reserved for storage capacity.
    // If an account has less then this amount reserved by the end of any transaction it participated in, the transaction will fail.
    pub var minimumStorageReservation: UFix64

    // An administrator resource that can change the parameters of the FlowStorageFees smart contract.
    pub resource Administrator {

        // Changes the amount of storage capacity an account has per accounts' reserved storage FLOW.
        pub fun setStorageBytesPerReservedFLOW(_ storageBytesPerReservedFLOW: UFix64) {
            if FlowStorageFees.storageBytesPerReservedFLOW == storageBytesPerReservedFLOW {
              return
            }
            FlowStorageFees.storageBytesPerReservedFLOW = storageBytesPerReservedFLOW
            emit StorageBytesPerReservedFLOWChanged(storageBytesPerReservedFLOW)
        }

        // Changes the minimum amount of FLOW an account has to have reserved.
        pub fun setMinimumStorageReservation(_ minimumStorageReservation: UFix64) {
            if FlowStorageFees.minimumStorageReservation == minimumStorageReservation {
              return
            }
            FlowStorageFees.minimumStorageReservation = minimumStorageReservation
            emit MinimumStorageReservationChanged(minimumStorageReservation)
        }

        access(contract) init(){}
    }

    pub fun flowToStorageCapacity(_ amount: UFix64): UInt64 {
        return UInt64(amount * FlowStorageFees.storageBytesPerReservedFLOW)
    }

    pub fun storageCapacityToFlow(_ amount: UInt64): UFix64 {
        // loss of precision
        // putting the result back into `flowToStorageCapacity` possibly won't yield the same result
        return UFix64(amount) / FlowStorageFees.storageBytesPerReservedFLOW
    }

    init() {
        self.storageBytesPerReservedFLOW = 1000000.0 // 1 Mb per 1 Flow token
        self.minimumStorageReservation = 0.1 // or 100 kb of storage capacity

        let admin <- create Administrator()
        self.account.save(<-admin, to: /storage/storageFeesAdmin)
    }
}