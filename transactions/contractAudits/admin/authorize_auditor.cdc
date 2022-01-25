/**
  
  Create a new Auditor resource in the admin storage and deposit
  a linked capability to the provided Auditor's account. 
  
  This mechanism enables the administrator to revoke audit access 
  by deleting the resource or capability.

  Before running this transaction, the auditor should have initialized their 
  account with auditor/init.cdc

*/

import FlowContractAudits from "../../../contracts/FlowContractAudits.cdc"

transaction(auditorAddress: Address) {    
    let auditorCapability: Capability<&FlowContractAudits.Auditor>

    prepare(adminAccount: AuthAccount) {

        // These paths must be unique within the contract account's storage for each auditor
        let resourceStoragePath = /storage/auditor_01
        let capabilityPrivatePath = /private/auditor_01

        // Create a reference to the admin resource in storage
        let auditorAdmin = adminAccount.borrow<&FlowContractAudits.Administrator>(from: FlowContractAudits.AdminStoragePath)
            ?? panic("Could not borrow a reference to the admin resource")

        // Create a new auditor resource and a private link to a capability to it in the admin's storage
        let auditor <- auditorAdmin.createNewAuditor()
        adminAccount.save(<- auditor, to: resourceStoragePath)
        self.auditorCapability = adminAccount.link<&FlowContractAudits.Auditor>(
            capabilityPrivatePath, target: resourceStoragePath
        ) ?? panic("Could not link auditor")

    }

    execute {
        // This is the account that the capability will be given to
        let auditorAccount = getAccount(auditorAddress)

        let capabilityReceiver = auditorAccount.getCapability
            <&FlowContractAudits.AuditorProxy{FlowContractAudits.AuditorProxyPublic}>
            (FlowContractAudits.AuditorProxyPublicPath)!
            .borrow() ?? panic("Could not borrow capability receiver reference")

        capabilityReceiver.setAuditorCapability(self.auditorCapability)        
    }

}