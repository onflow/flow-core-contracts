// Clean up expired vouchers by current block height.

import FlowContractAudits from "../../../contracts/FlowContractAudits.cdc"

transaction() {
    let auditorAdmin: &FlowContractAudits.Administrator
    
    prepare(adminAccount: AuthAccount) {        
        self.auditorAdmin = adminAccount.borrow<&FlowContractAudits.Administrator>(from: FlowContractAudits.AdminStoragePath)
            ?? panic("Could not borrow a reference to the admin resource")        
    }

    execute {
        self.auditorAdmin.cleanupExpiredVouchers()             
    }
}