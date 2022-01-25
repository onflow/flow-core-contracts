/**
  
  Removes an audit voucher by dictionary key.
  
  The key format is address-codeHash for account specific vouchers
  and any-codeHash for recurrent vouchers.

  The current vouchers dictionary can be retrieved with scripts/get_vouchers.cdc

*/

import FlowContractAudits from "../../../contracts/FlowContractAudits.cdc"

transaction(key: String) {
    
    let auditorCapability: &FlowContractAudits.AuditorProxy

    prepare(auditorAccount: AuthAccount) {
        self.auditorCapability = auditorAccount
            .borrow<&FlowContractAudits.AuditorProxy>(from: FlowContractAudits.AuditorProxyStoragePath)
            ?? panic("Could not borrow a reference to the auditor resource")
    }

    execute {
        self.auditorCapability.deleteVoucher(key: key)        
    }
}
 