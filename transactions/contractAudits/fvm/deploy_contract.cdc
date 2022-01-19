import FlowContractAudits from "../../../contracts/FlowContractAudits.cdc"

// emulates fvm call for tests
transaction(address: Address, code: String) {
    let auditorAdmin: &FlowContractAudits.Administrator
    
    prepare(adminAccount: AuthAccount) {        
        self.auditorAdmin = adminAccount.borrow<&FlowContractAudits.Administrator>(from: FlowContractAudits.AdminStoragePath)
            ?? panic("Could not borrow a reference to the admin resource")        
    }

    execute {
        if !self.auditorAdmin.useVoucherForDeploy(address: address, code: code) {
            panic("invalid voucher")
        }    
    }
}