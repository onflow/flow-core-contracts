/**
  
  Create a new contract audit voucher for deployment.

  Parameters:

  `address`: If nil, the contract can be deployed to any account.

  `codeHash`: Hex encoded SHA3-256 hash of the contract code. hashContractCode
              function can be called on the contract to produce the hash.

  `recurrent`: If true, the voucher will not be removed with the first
               contract deployment and can be used for multiple deployments.

  `expiryOffset`: If nil, the voucher will not expire by block height. 
                  If provided, the voucher will expire at
                   expiryOffset + currentBlockHeight

*/

import FlowContractAudits from "../../../contracts/FlowContractAudits.cdc"

transaction(address: Address?, codeHash: String, recurrent: Bool, expiryOffset: UInt64?) {
    
    let auditorCapability: &FlowContractAudits.AuditorProxy

    prepare(auditorAccount: AuthAccount) {
        self.auditorCapability = auditorAccount
            .borrow<&FlowContractAudits.AuditorProxy>(from: FlowContractAudits.AuditorProxyStoragePath)
            ?? panic("Could not borrow a reference to the auditor resource")
    }

    execute {
        self.auditorCapability.addVoucherHashed(address: address, recurrent: recurrent, expiryOffset: expiryOffset, codeHash: codeHash)        
    }
}