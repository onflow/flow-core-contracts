import FlowContractAudits from "../../../contracts/FlowContractAudits.cdc"

transaction(address: Address?, code: String, recurrent: Bool, expiryOffset: UInt64?) {
    
    let auditorCapability: &FlowContractAudits.AuditorProxy

    prepare(auditorAccount: AuthAccount) {
        self.auditorCapability = auditorAccount
            .borrow<&FlowContractAudits.AuditorProxy>(from: FlowContractAudits.AuditorProxyStoragePath)
            ?? panic("Could not borrow a reference to the admin resource")
    }

    execute {
        self.auditorCapability.addVoucher(address: address, recurrent: recurrent, expiryOffset: expiryOffset, code: code)        
    }
}