import StorageFees from 0xSTORAGEFEES
import FlowToken from 0xFLOWTOKENADDRESS

// This transaction sets up storage on any auth accounts that were created before the storage fees.
// This is used during bootstrapping a local environment 
transaction() {
    prepare(service: AuthAccount, fungibleToken: AuthAccount, flowToken: AuthAccount, feeContract: AuthAccount) {
        let authAccounts = [service, fungibleToken, flowToken, feeContract]

        // take all the funds from the service account
        let tokenVault = service.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault) ?? panic("Unable to borrow reference to the default token vault")
        
        for a in authAccounts {
            StorageFees.setupAccountStorage(account: a, storageReservation: <- (tokenVault.withdraw(amount: StorageFees.minimumStorageReservation) as! @FlowToken.Vault))
        }
    }
}