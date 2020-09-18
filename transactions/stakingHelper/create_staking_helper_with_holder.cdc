import FungibleToken from 0xee82856bf20e2aa6
import FlowIDTableStaking from 0xe03daebed8ca0615
import FlowStakingHelper from 0x045a1763c93006ca

transaction(stakingKey: String, networkingKey: String, networkingAddress: String, 
            nodeAwardReceiver: Address, stakerAwardReceiver: Address, 
            cutPercentage: UFix64) {

    let node: AuthAccount
    let staker: AuthAccount
    let holder: AuthAccount

    let storagePath: Path
    let linkPath: Path
    let flowReceiverPath: Path

    prepare(staker: AuthAccount, node: AuthAccount, holder: AuthAccount) {
        // assign accounts
        self.staker = staker
        self.node = node
        self.holder = holder

        // assign path values
        self.storagePath = FlowStakingHelper.HelperStoragePath
        self.linkPath = /public/flowStakingHelper
        self.flowReceiverPath = /public/flowTokenReceiver
    }

    execute{
        // Create new account to store stakingHelper resource


        // Create new StakingHelper
        // TODO: Do we need to check if capability exists? 🤔
        // TODO: How about we create new empty vaults here and store them in place, where we can find them?
        let nodeAwardVaultCapability = getAccount(nodeAwardReceiver).getCapability(self.flowReceiverPath)!
        let stakerAwardVaultCapability = getAccount(stakerAwardReceiver).getCapability(self.flowReceiverPath)!

        let helper <- FlowStakingHelper.createHelper(stakingKey: stakingKey, 
                                                networkingKey: networkingKey, 
                                                networkingAddress:networkingAddress,
                                                stakerAwardVaultCapability: stakerAwardVaultCapability,
                                                nodeAwardVaultCapability: nodeAwardVaultCapability,
                                                cutPercentage: cutPercentage)
        
        // Save newly created StakingHelper into newAccount storage
        self.holder.save<@FlowStakingHelper.StakingHelper>(<- helper, to: self.storagePath)

        // Create capability to stored StakingHelper
        // TODO: Create another one for restricted NodeHelper capability
        self.holder.link<&FlowStakingHelper.StakingHelper>(self.linkPath, target: self.storagePath)    
        let capability = self.holder.getCapability(self.linkPath)

        // clear storages before saving anything, remove after tests
        self.node.load<Capability>(from: self.storagePath)
        self.staker.load<Capability>(from: self.storagePath)
        
        // Save capabilities to storage
        self.node.save(capability!, to: self.storagePath)
        self.staker.save(capability!, to: self.storagePath)
    }

    post {
        /* 
        // TODO: Check that capability of restricted type
        self.node
            .copy<Capability>(from: self.storagePath)!
            .check<&FlowStakingHelper.StakingHelper>():
            "StakingHelper capability on node account wasn't saved properly"

        self.staker
            .copy<Capability>(from: self.storagePath)!
            .check<&FlowStakingHelper.StakingHelper>():
            "StakingHelper capability on staker account wasn't saved properly"
        */
    }
}
 