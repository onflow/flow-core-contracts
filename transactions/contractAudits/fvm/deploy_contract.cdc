/**
  
  Emulate FVM call for tests. 

  The FVM calls FlowContractAudits.useVoucherForDeploy on contract deployment.
  This call cannot be made in the emulator since the function is scoped as 
  access(contract). As a workaround the Administrator resource also provides
  useVoucherForDeploy that calls FlowContractAudits.useVoucherForDeploy
  
*/

import FlowContractAudits from "../../../contracts/FlowContractAudits.cdc"

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