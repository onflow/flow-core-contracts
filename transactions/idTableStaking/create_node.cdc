import FlowIDTableStaking from 0xIDENTITYTABLEADDRESS
import FlowToken from 0xFLOWTOKENADDRESS

// This transaction creates a new node struct object
// and updates the proposed Identity Table

transaction(id: String, 
            role: UInt8, 
            networkingAddress: String, 
            networkingKey: String, 
            stakingKey: String, 
            amount: UFix64,
            cutPercentage: UFix64) {

    let flowTokenRef: &FlowToken.Vault

    prepare(acct: AuthAccount) {

        self.flowTokenRef = acct.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to FLOW Vault")

        let nodeStaker <- FlowIDTableStaking.addNodeRecord(id: id, 
                                    role: role, 
                                    networkingAddress: networkingAddress, 
                                    networkingKey: networkingKey, 
                                    stakingKey: stakingKey, 
                                    tokensCommitted: <-self.flowTokenRef.withdraw(amount: amount),
                                    cutPercentage: cutPercentage)

        
        if acct.borrow<&FlowIDTableStaking.NodeStaker>(from: FlowIDTableStaking.NodeStakerStoragePath) == nil {
            acct.save(<-nodeStaker, to: FlowIDTableStaking.NodeStakerStoragePath)
        } else {
            destroy nodeStaker
        }
    }
}