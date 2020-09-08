import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS
import FlowToken from 0xFLOWTOKENADDRESS

// This transaction creates a new node struct object
// and updates the proposed Identity Table

transaction(adminAddress: Address,
            id: String, 
            role: UInt8, 
            networkingAddress: String, 
            networkingKey: String, 
            stakingKey: String, 
            amount: UFix64) {

    // Local variable for a reference to the ID Table Admin object
    let adminRef: &FlowIDTableStaking.Admin

    let flowTokenRef: &FlowToken.Vault

    prepare(acct: AuthAccount) {

        // borrow a reference to the admin object
        self.adminRef = getAccount(adminAddress).getCapability<&FlowIDTableStaking.Admin>(/public/flowStakingAdmin)!
            .borrow() ?? panic("Could not borrow reference to staking admin")

        self.flowTokenRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to FLOW Vault")

        let nodeStaker <- self.adminRef.addNodeRecord(id: id, 
                                    role: role, 
                                    networkingAddress: networkingAddress, 
                                    networkingKey: networkingKey, 
                                    stakingKey: stakingKey, 
                                    tokensCommitted: <-self.flowTokenRef.withdraw(amount: amount))

        
        if acct.borrow<&FlowIDTableStaking.NodeStaker>(from: FlowIDTableStaking.NodeStakerStoragePath) == nil {
            acct.save(<-nodeStaker, to: FlowIDTableStaking.NodeStakerStoragePath)
        } else {
            destroy nodeStaker
        }
    }
}