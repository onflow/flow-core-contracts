/*
 * The FlowStorageFees smart contract
 *
 * An account's storage capacity determines up to how much storage on chain it can use. 
 * A storage capacity is calculated by multiplying the amount of reserved flow with `StorageFee.storageMegaBytesPerReservedFLOW`
 * The minimum amount of flow tokens reserved for storage capacity is `FlowStorageFees.minimumStorageReservation` this is paid during account creation, by the creator.
 * 
 * At the end of all transactions, any account that had any value changed in their storage 
 * has their storage capacity checked against their storage used and their main flow token vault against the minimum reservation.
 * If any account fails this check the transaction wil fail.
 * 
 * An account moving/deleting its `FlowToken.Vault` resource will result 
 * in the transaction failing because the account will have no storage capacity.
 * 
 */

import "FungibleToken"
import "FlowToken"

access(all) contract FlowStorageFees {

    // Emitted when the amount of storage capacity an account has per reserved Flow token changes
    access(all) event StorageMegaBytesPerReservedFLOWChanged(_ storageMegaBytesPerReservedFLOW: UFix64)

    // Emitted when the minimum amount of Flow tokens that an account needs to have reserved for storage capacity changes.
    access(all) event MinimumStorageReservationChanged(_ minimumStorageReservation: UFix64)

    // Defines how much storage capacity every account has per reserved Flow token.
    // definition is written per unit of flow instead of the inverse, 
    // so there is no loss of precision calculating storage from flow, 
    // but there is loss of precision when calculating flow per storage.
    access(all) var storageMegaBytesPerReservedFLOW: UFix64

    // Defines the minimum amount of Flow tokens that every account needs to have reserved for storage capacity.
    // If an account has less then this amount reserved by the end of any transaction it participated in, the transaction will fail.
    access(all) var minimumStorageReservation: UFix64

    // An administrator resource that can change the parameters of the FlowStorageFees smart contract.
    access(all) resource Administrator {

        // Changes the amount of storage capacity an account has per accounts' reserved storage FLOW.
        access(all) fun setStorageMegaBytesPerReservedFLOW(_ storageMegaBytesPerReservedFLOW: UFix64) {
            if FlowStorageFees.storageMegaBytesPerReservedFLOW == storageMegaBytesPerReservedFLOW {
              return
            }
            FlowStorageFees.storageMegaBytesPerReservedFLOW = storageMegaBytesPerReservedFLOW
            emit StorageMegaBytesPerReservedFLOWChanged(storageMegaBytesPerReservedFLOW)
        }

        // Changes the minimum amount of FLOW an account has to have reserved.
        access(all) fun setMinimumStorageReservation(_ minimumStorageReservation: UFix64) {
            if FlowStorageFees.minimumStorageReservation == minimumStorageReservation {
              return
            }
            FlowStorageFees.minimumStorageReservation = minimumStorageReservation
            emit MinimumStorageReservationChanged(minimumStorageReservation)
        }

        access(contract) init(){}
    }

    /// calculateAccountCapacity returns the storage capacity of an account
    ///
    /// Returns megabytes
    /// If the account has no default balance it is counted as a balance of 0.0 FLOW
    access(all) fun calculateAccountCapacity(_ accountAddress: Address): UFix64 {
        var balance = 0.0
        let acct = getAccount(accountAddress)

        if let balanceRef = acct.capabilities.borrow<&FlowToken.Vault>(/public/flowTokenBalance) {
            balance = balanceRef.balance
        }

        return self.accountBalanceToAccountStorageCapacity(balance)
    }

    /// calculateAccountsCapacity returns the storage capacity of a batch of accounts
    access(all) fun calculateAccountsCapacity(_ accountAddresses: [Address]): [UFix64] {
        let capacities: [UFix64] = []
        for accountAddress in accountAddresses {
            let capacity = self.calculateAccountCapacity(accountAddress)
            capacities.append(capacity)
        }
        return capacities
    }

    // getAccountsCapacityForTransactionStorageCheck returns the storage capacity of a batch of accounts
    // This is used to check if a transaction will fail because of any account being over the storage capacity
    // The payer is an exception as its storage capacity is derived from its balance minus the maximum possible transaction fees 
    // (transaction fees if the execution effort is at the execution efort limit, a.k.a.: computation limit, a.k.a.: gas limit)
    access(all) fun getAccountsCapacityForTransactionStorageCheck(accountAddresses: [Address], payer: Address, maxTxFees: UFix64): [UFix64] {
        let capacities: [UFix64] = []
        for accountAddress in accountAddresses {
            var balance = 0.0
            let acct = getAccount(accountAddress)

            if let balanceRef = acct.capabilities.borrow<&FlowToken.Vault>(/public/flowTokenBalance) {
                if accountAddress == payer {
                    // if the account is the payer, deduct the maximum possible transaction fees from the balance
                    balance = balanceRef.balance.saturatingSubtract(maxTxFees)
                } else {
                    balance = balanceRef.balance
                }
            }

            capacities.append(self.accountBalanceToAccountStorageCapacity(balance)) 
        }
        return capacities
    }

    // accountBalanceToAccountStorageCapacity returns the storage capacity
    // an account would have with given the flow balance of the account.
    access(all) view fun accountBalanceToAccountStorageCapacity(_ balance: UFix64): UFix64 {
        // get address token balance
        if balance < self.minimumStorageReservation {
            // if < then minimum return 0
            return 0.0
        }

        // return balance multiplied with megabytes per flow 
        return self.flowToStorageCapacity(balance)
    }

    // Amount in Flow tokens
    // Returns megabytes
    access(all) view fun flowToStorageCapacity(_ amount: UFix64): UFix64 {
        return amount.saturatingMultiply(FlowStorageFees.storageMegaBytesPerReservedFLOW)
    }

    // Amount in megabytes
    // Returns Flow tokens
    access(all) view fun storageCapacityToFlow(_ amount: UFix64): UFix64 {
        if FlowStorageFees.storageMegaBytesPerReservedFLOW == 0.0 {
            return 0.0
        }
        // possible loss of precision
        // putting the result back into `flowToStorageCapacity` might not yield the same result
        return amount / FlowStorageFees.storageMegaBytesPerReservedFLOW
    }

    // converts storage used from UInt64 Bytes to UFix64 Megabytes.
    access(all) view fun convertUInt64StorageBytesToUFix64Megabytes(_ storage: UInt64): UFix64 {
        // safe convert UInt64 to UFix64 (without overflow)
        let f = UFix64(storage % 100000000) * 0.00000001 + UFix64(storage / 100000000)
        // decimal point correction. Megabytes to bytes have a conversion of 10^-6 while UFix64 minimum value is 10^-8
        let storageMb = f.saturatingMultiply(100.0)
        return storageMb
    }

    /// Gets "available" balance of an account
    ///
    /// The available balance of an account is its default token balance minus what is reserved for storage.
    /// If the account has no default balance it is counted as a balance of 0.0 FLOW
    access(all) fun defaultTokenAvailableBalance(_ accountAddress: Address): UFix64 {
        //get balance of account
        let acct = getAccount(accountAddress)
        var balance = 0.0

        if let balanceRef = acct.capabilities.borrow<&FlowToken.Vault>(/public/flowTokenBalance) {
            balance = balanceRef.balance
        }

        // get how much should be reserved for storage
        var reserved = self.defaultTokenReservedBalance(accountAddress)

        return balance.saturatingSubtract(reserved)
    }

    /// Gets "reserved" balance of an account
    ///
    /// The reserved balance of an account is its storage used multiplied by the storage cost per flow token.
    /// The reserved balance is at least the minimum storage reservation.
    access(all) view fun defaultTokenReservedBalance(_ accountAddress: Address): UFix64 {
        let acct = getAccount(accountAddress)
        var reserved = self.storageCapacityToFlow(self.convertUInt64StorageBytesToUFix64Megabytes(acct.storage.used))
        // at least self.minimumStorageReservation should be reserved
        if reserved < self.minimumStorageReservation {
            reserved = self.minimumStorageReservation
        }

        return reserved
    }

    init() {
        self.storageMegaBytesPerReservedFLOW = 1.0 // 1 Mb per 1 Flow token
        self.minimumStorageReservation = 0.0 // or 0 kb of minimum storage reservation

        let admin <- create Administrator()
        self.account.storage.save(<-admin, to: /storage/storageFeesAdmin)
    }
}
 