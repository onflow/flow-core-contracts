/**
  
  Initialize the auditor account by creating an empty AuditorProxy.

  After this transaction, the admin will have to run admin/authorize_auditor.cdc
  to deposit an Auditor capability into the proxy.

*/

import FlowContractAudits from "../../../contracts/FlowContractAudits.cdc"

transaction {

    prepare(auditor: AuthAccount) {

        let auditorProxy <- FlowContractAudits.createAuditorProxy()

        auditor.save(
            <- auditorProxy, 
            to: FlowContractAudits.AuditorProxyStoragePath,
        )
            
        auditor.link<&FlowContractAudits.AuditorProxy{FlowContractAudits.AuditorProxyPublic}>(
            FlowContractAudits.AuditorProxyPublicPath,
            target: FlowContractAudits.AuditorProxyStoragePath
        )
    }
}