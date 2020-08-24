/*

    FlowIDTableStaking

    The Flow ID Table and Staking contract manages node operators' information 
    and flow tokens that are staked as part of the Flow Protocol.

    Nodes submit their stake to the Admin's addNodeInfo Function
    during the staking auction phase.
    This records their info and committd tokens. They also will get a Node
    Object that they can use to stake, unstake, and withdraw rewards.

    The Admin has the authority to remove node records, 
    refund insufficiently staked nodes, pay rewards, 
    and move tokens between buckets.

    All the node info an staking info is publicly accessible
    to any transaction in the network

 */

import FungibleToken from 0xee82856bf20e2aa6
import FlowToken from 0x0ae53cb6e3f42a79

pub contract FlowIDTableStaking {

    /****************** ID Table and Staking Events *******************/
    pub event NewNodeCreated(nodeID: String, amountCommitted: UFix64)
    pub event TokensCommitted(nodeID: String, amount: UFix64)
    pub event TokensStaked(nodeID: String, amount: UFix64)
    pub event TokensUnStaked(nodeID: String, amount: UFix64)
    pub event NodeRemovedAndRefunded(nodeID: String, amount: UFix64)
    pub event RewardsPaid(nodeID: String, amount: UFix64)
    pub event TokensWithdrawn(nodeID: String, amount: UFix64)

    /// Holds the identity table for all the nodes in the network.
    /// Includes nodes that aren't actively participating
    access(contract) var nodes: @{String: NodeRecord}

    /// The minimum amount of tokens that each node type has to stake
    /// in order to be considered valid
    access(contract) var minimumStakeRequired: {UInt8: UFix64}

    /// The total amount of tokens that are staked for all the nodes
    /// of each node type during the current epoch
    access(contract) var totalTokensStakedByNodeType: {UInt8: UFix64}

    /// The total amount of tokens that are paid as rewards every epoch
    pub var weeklyTokenPayout: UFix64

    /// The ratio of the weekly awards that each node type gets
    access(contract) var rewardRatios: {UInt8: UFix64}

    // Mints Flow tokens for staking rewards
    access(contract) let flowTokenMinter: @FlowToken.Minter

    /// Contains information that is specific to a node in Flow
    /// only lives in this contract
    pub resource NodeRecord {

        /// The unique ID of the node
        /// Set when the node is created
        pub let id: String

        /// The type of node: 
        /// 1 = collection
        /// 2 = consensus
        /// 3 = execution
        /// 4 = verification
        /// 5 = access
        pub var role: UInt8

        /// The address used for networking
        pub(set) var networkingAddress: String

        /// the public key for networking
        pub(set) var networkingKey: String

        /// the public key for staking
        pub(set) var stakingKey: String

        /// The tokens that this node has staked for the current epoch.
        pub var tokensStaked: @FlowToken.Vault

        /// The tokens that this node has committed to stake for the next epoch.
        pub var tokensCommitted: @FlowToken.Vault

        /// The tokens that this node has unstaked from the previous epoch
        /// Moves to the tokensUnlocked bucket at the end of the epoch.
        pub var tokensUnstaked: @FlowToken.Vault

        /// Tokens that this node is able to withdraw whenever they want
        /// Staking rewards are paid to this bucket
        pub var tokensUnlocked: @FlowToken.Vault

        /// The amount of tokens that this node has requested to unstake
        /// for the next epoch
        pub(set) var tokensRequestedToUnstake: UFix64

        /// weight as determined by the amount staked after the staking auction
        pub(set) var initialWeight: UInt64

        init(id: String, role: UInt8, networkingAddress: String, networkingKey: String, stakingKey: String, tokensCommitted: @FlowToken.Vault) {
            pre {
                id.length == 64: "Node ID length must be 32 bytes (64 hex characters)"
                FlowIDTableStaking.nodes[id] == nil: "The ID cannot already exist in the record"
                role >= UInt8(1) && role <= UInt8(5): "The role must be 1, 2, 3, 4, or 5"
                networkingAddress.length > 0: "The networkingAddress cannot be empty"
            }

            if role == UInt8(5) {
                assert (
                    tokensCommitted.balance == 0.0,
                    message: "Access Nodes cannot stake and tokens"
                )
            }

            /// Assert that the addresses and keys are not already in use for the proposed nodes
            /// They must be unique
            for nodeID in FlowIDTableStaking.nodes.keys {
                assert (
                    networkingAddress != FlowIDTableStaking.nodes[nodeID]?.networkingAddress,
                    message: "Networking Address is already in use!"
                )
                assert (
                    networkingKey != FlowIDTableStaking.nodes[nodeID]?.networkingKey,
                    message: "Networking Key is already in use!"
                )
                assert (
                    stakingKey != FlowIDTableStaking.nodes[nodeID]?.stakingKey,
                    message: "Staking Key is already in use!"
                )
            }

            self.id = id
            self.role = role
            self.networkingAddress = networkingAddress
            self.networkingKey = networkingKey
            self.stakingKey = stakingKey
            self.initialWeight = 0

            self.tokensCommitted <- tokensCommitted
            self.tokensStaked <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.tokensUnstaked <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.tokensUnlocked <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.tokensRequestedToUnstake = 0.0
        }

        destroy() {
            destroy self.tokensStaked
            destroy self.tokensCommitted
            destroy self.tokensUnstaked
            destroy self.tokensUnlocked
        }
    }

    /// Resource that the node operator controls for participating
    /// in the staking auction and other Epoch phases.
    /// This resource will be wrapped by the Node resource 
    /// in the Epoch smart contract, so the node operator will not
    /// be able to call these functions directly. The `Node` resource
    /// will provide the `nodeID` arguments from its ID field.
    pub resource NodeStaker {

        /// Add new tokens to the system to stake during the next epoch
        pub fun stakeNewTokens(nodeID: String, _ tokens: @FungibleToken.Vault) {

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

            assert (
                nodeRecord.role != UInt8(5),
                message: "Access Nodes Cannot stake tokens"
            )

            /// Add the new tokens to tokens committed
            nodeRecord.tokensCommitted.deposit(from: <-tokens)

        }

        /// Stake tokens that are in the tokensUnlocked bucket 
        /// but haven't been officially staked
        pub fun stakeUnlockedTokens(nodeID: String, amount: UFix64) {

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

            assert (
                nodeRecord.role != UInt8(5),
                message: "Access Nodes Cannot stake tokens"
            )

            assert (
                nodeRecord.tokensUnlocked.balance >= amount,
                message: "Not enough unlocked tokens to stake!"
            )

            /// Add the removed tokens to tokens committed
            nodeRecord.tokensCommitted.deposit(from: <-nodeRecord.tokensUnlocked.withdraw(amount: amount))
        }

        /// Request amount tokens to be removed from staking
        /// at the end of the next epoch
        pub fun requestUnStaking(nodeID: String, amount: UFix64) {

            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

            assert (
                nodeRecord.role != UInt8(5),
                message: "Access Nodes Cannot stake tokens"
            )

            assert (
                nodeRecord.tokensStaked.balance + 
                nodeRecord.tokensCommitted.balance 
                >= amount + nodeRecord.tokensRequestedToUnstake,
                message: "Not enough tokens to unstake!"
            )

            /// if the request can come from committed, withdraw from committed to unlocked
            if nodeRecord.tokensCommitted.balance >= amount {

                /// withdraw the requested tokens from committed since they have not been staked yet
                let tokens <- nodeRecord.tokensCommitted.withdraw(amount: amount)

                /// add the withdrawn tokens to tokensUnlocked
                nodeRecord.tokensUnlocked.deposit(from: <-tokens)
            } else {
                /// Get the balance of the tokens that are currently committed
                let amountCommitted = nodeRecord.tokensCommitted.balance

                /// Withdraw all the tokens from the committed field
                let tokens <- nodeRecord.tokensCommitted.withdraw(amount: amountCommitted)

                nodeRecord.tokensUnlocked.deposit(from: <-tokens)

                /// update request to show that leftover amount is requested to be unstaked
                /// at the end of the current epoch
                nodeRecord.tokensRequestedToUnstake = amount - amountCommitted
            }  
        }

        /// Withdraw tokens from the unlocked bucket
        pub fun withdrawUnlockedTokens(nodeID: String, amount: UFix64): @FungibleToken.Vault {
            let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

            assert (
                nodeRecord.role != UInt8(5),
                message: "Access Nodes Cannot stake tokens"
            )

            /// remove the tokens from the unlocked bucket
            let tokens <- nodeRecord.tokensUnlocked.withdraw(amount: amount)

            return <-tokens
        }

    }

    /// Admin resource that has the ability to create new staker objects,
    /// remove insufficiently staked nodes at the end of the staking auction,
    /// and pay rewards to nodes at the end of an epoch
    pub resource StakingAdmin {

        /// Add a new node to the record
        pub fun addNodeInfo(id: String, role: UInt8, networkingAddress: String, networkingKey: String, stakingKey: String, initialWeight: UInt64, tokensCommitted: @FlowToken.Vault) {

            // Insert the node to the table
            FlowIDTableStaking.nodes[id] <-! create NodeRecord(id: id, role: role, networkingAddress: networkingAddress, networkingKey: networkingKey, stakingKey: stakingKey, tokensCommitted: <-tokensCommitted)
        }

        /// Remove a node from the record
        pub fun removeNodeInfo(_ nodeID: String): @NodeRecord {

            // Remove the node from the table
            let node <- FlowIDTableStaking.nodes.remove(key: nodeID)
                ?? panic("Could not find a node with the specified ID")

            return <-node
        }

        /// Iterates through all the registered nodes and if it finds
        /// a node that has insufficient tokens committed for the next epoch
        /// it moves their committed tokens to their unlocked bucket
        /// This will only be called once per epoch
        /// after the staking auction phase
        ///
        /// Also sets the initial weight of all the accepted nodes
        pub fun endStakingAuction() {

            let allNodeIDs = FlowIDTableStaking.getNodeIDs()

            /// remove nodes that have insufficient stake
            for nodeID in allNodeIDs {

                let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

                let totalTokensCommitted = nodeRecord.tokensCommitted.balance + nodeRecord.tokensStaked.balance - nodeRecord.tokensRequestedToUnstake

                /// If the tokens that they have committed for the next epoch
                /// do not meet the minimum requirements
                if totalTokensCommitted < FlowIDTableStaking.minimumStakeRequired[nodeRecord.role]! {
                    /// move their committed tokens back to their unlocked tokens
                    nodeRecord.tokensUnlocked.deposit(from: <-nodeRecord.tokensCommitted.withdraw(amount: nodeRecord.tokensCommitted.balance))

                    /// Add the rest of their staked tokens to their request since they have to unstake
                    nodeRecord.tokensRequestedToUnstake = nodeRecord.tokensStaked.balance
                } else {
                    /// Set initial weight of all the committed nodes
                    nodeRecord.initialWeight = UInt64(totalTokensCommitted % 1.0)
                }
            }
        }

        /// Called at the end of the epoch to pay rewards to node operators
        /// based on the tokens that they have staked
        pub fun payRewards() {

            let allNodeIDs = FlowIDTableStaking.getNodeIDs()

            /// iterate through all the nodes
            for nodeID in allNodeIDs {

                let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

                /// Calculate the amount of tokens that this node operator receives
                let rewardAmount = FlowIDTableStaking.weeklyTokenPayout * FlowIDTableStaking.rewardRatios[nodeRecord.role]! * (nodeRecord.tokensStaked.balance/FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role]!)

                /// Mint the tokens to reward the operator
                let tokensRewarded <- FlowIDTableStaking.flowTokenMinter.mintTokens(amount: rewardAmount)

                /// Deposit the tokens into their tokensUnlocked bucket
                nodeRecord.tokensUnlocked.deposit(from: <-tokensRewarded)    
            }
        }

        /// Called at the end of the epoch to move tokens between buckets
        /// for stakers
        /// Tokens that have been committed are moved to the staked bucket
        /// Tokens that were unstaked during the last epoch are fully unlocked
        /// Unstaking requests are filled by moving those tokens from staked to unstaked
        pub fun moveTokens() {
            
            let allNodeIDs = FlowIDTableStaking.getNodeIDs()

            /// remove nodes that have insufficient stake
            for nodeID in allNodeIDs {

                let nodeRecord = FlowIDTableStaking.borrowNodeRecord(nodeID)

                // Update total number of tokens staked by all the nodes of each type
                FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role] = FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role]! + nodeRecord.tokensCommitted.balance

                nodeRecord.tokensStaked.deposit(from: <-nodeRecord.tokensCommitted.withdraw(amount: nodeRecord.tokensCommitted.balance))
                nodeRecord.tokensUnlocked.deposit(from: <-nodeRecord.tokensUnstaked.withdraw(amount: nodeRecord.tokensUnstaked.balance))
                nodeRecord.tokensUnstaked.deposit(from: <-nodeRecord.tokensStaked.withdraw(amount: nodeRecord.tokensRequestedToUnstake))

                // subtract their requested tokens from the total staked for their node type
                FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role] = FlowIDTableStaking.totalTokensStakedByNodeType[nodeRecord.role]! - nodeRecord.tokensRequestedToUnstake

                // Reset the tokens requested field so it can be used for the next epoch
                nodeRecord.tokensRequestedToUnstake = 0.0
            }
        }
    }

    /// borrow a reference to to one of the nodes in the record
    /// This gives the caller access to all the public fields on the
    /// objects and is basically as if the caller owned the object
    /// The only thing they cannot do is destroy it or move it
    /// This will only be used by the other epoch contracts
    access(contract) fun borrowNodeRecord(_ nodeID: String): &NodeRecord {
        return &FlowIDTableStaking.nodes[nodeID] as! &NodeRecord
    }

    /****************** Getter Functions for the node Info *******************/

    /// Gets an array of the node IDs that are proposed for the next epoch
    /// Nodes that are proposed are nodes that have tokens staked + committed
    /// for the next epoch
    pub fun getProposedNodeIDs(): [String] {
        var proposedNodes: [String] = []

        for nodeID in FlowIDTableStaking.getNodeIDs() {
            let record = FlowIDTableStaking.borrowNodeRecord(nodeID)

            if record.tokensCommitted.balance + record.tokensStaked.balance - record.tokensRequestedToUnstake > self.minimumStakeRequired[record.role]!  {
                proposedNodes.append(nodeID)
            }
        }

        return proposedNodes
    }

    /// Gets an array of all the nodeIDs that are staked.
    /// Only nodes that are participating in the current epoch
    /// can be staked, so this is an array of all the active 
    /// node operators
    pub fun getStakedNodeIDs(): [String] {
        var stakedNodes: [String] = []

        for nodeID in FlowIDTableStaking.getNodeIDs() {
            let record = FlowIDTableStaking.borrowNodeRecord(nodeID)

            if record.tokensStaked.balance > self.minimumStakeRequired[record.role]!  {
                stakedNodes.append(nodeID)
            }
        }

        return stakedNodes
    }

    /// Gets an array of all the node IDs that have ever applied
    pub fun getNodeIDs(): [String] {
        return FlowIDTableStaking.nodes.keys
    }

    /// Gets the role of the specified node
    pub fun getNodeRole(nodeID: String): UInt8? {
        return FlowIDTableStaking.nodes[nodeID]?.role
    }

    /// Gets the networking Address of the specified node
    pub fun getNodeNetworkingAddress(nodeID: String): String? {
        return FlowIDTableStaking.nodes[nodeID]?.networkingAddress
    }

    /// Gets the networking key of the specified node
    pub fun getNodeNetworkingKey(nodeID: String): String? {
        return FlowIDTableStaking.nodes[nodeID]?.networkingKey
    }

    /// Gets the staking key of the specified node
    pub fun getNodeStakingKey(nodeID: String): String? {
        return FlowIDTableStaking.nodes[nodeID]?.stakingKey
    }

    /// Gets the initial weight of the specified node
    pub fun getNodeInitialWeight(nodeID: String): UInt64? {
        return FlowIDTableStaking.nodes[nodeID]?.initialWeight
    }

    /// Gets the total token balance that the specified node currently has staked
    pub fun getNodeStakedBalance(nodeID: String): UFix64? {
        let nodeRecord = self.borrowNodeRecord(nodeID)

        return nodeRecord.tokensStaked.balance
    }

    /// Gets the token balance that the specified node has committed
    /// to add to their stake for the next epoch
    pub fun getNodeCommittedBalance(nodeID: String): UFix64? {
        let nodeRecord = self.borrowNodeRecord(nodeID)

        return nodeRecord.tokensCommitted.balance
    }

    /// Gets the token balance that the specified node has unsteked
    /// from the previous epoch
    pub fun getNodeUnStakedBalance(nodeID: String): UFix64? {
        let nodeRecord = self.borrowNodeRecord(nodeID)

        return nodeRecord.tokensUnstaked.balance
    }

    /// Gets the token balance that the specified node can freely withdraw
    pub fun getNodeUnlockedBalance(nodeID: String): UFix64? {
        let nodeRecord = self.borrowNodeRecord(nodeID)

        return nodeRecord.tokensUnlocked.balance
    }

    init() {
        self.nodes <- {}

        // These are just arbitrary numbers right now
        self.minimumStakeRequired = {UInt8(1): 125000.0, UInt8(2): 250000.0, UInt8(3): 625000.0, UInt8(4): 67500.0, UInt8(5): 0.0}

        self.totalTokensStakedByNodeType = {UInt8(1): 0.0, UInt8(2): 0.0, UInt8(3): 0.0, UInt8(4): 0.0, UInt8(5): 0.0}

        // Arbitrary number for now
        self.weeklyTokenPayout = 250000000.0

        // The preliminary percentage of rewards that go to each node type every epoch
        // subject to change
        self.rewardRatios = {UInt8(1): 0.168, UInt8(2): 0.518, UInt8(3): 0.078, UInt8(4): 0.236, UInt8(5): 0.0}

        /// Borrow a reference to the Flow Token Admin in the account storage
        let flowTokenAdmin = self.account.borrow<&FlowToken.Administrator>(from: /storage/flowTokenAdmin)
            ?? panic("Could not borrow a reference to the Flow Token Admin resource")

        /// Create a flowTokenMinterResource
        self.flowTokenMinter <- flowTokenAdmin.createNewMinter(allowedAmount: 100.0)
    }
}
 