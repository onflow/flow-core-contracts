/*

    FlowStaking

    The Flow Staking contract manages node operators' flow tokens
    that are staked as part of the Flow Protocol.

    Nodes submit their stake during the staking auction and receive
    a resource object that they store in their account
    to interact with their stake.

 */


import FlowIdentityTable from 0x01cf0e2f2f715450
import FungibleToken from 0xee82856bf20e2aa6
import FlowToken from 0x0ae53cb6e3f42a79

pub contract FlowStaking {

    pub event NewStakerCreated(nodeID: String, amountCommitted: UFix64)
    pub event TokensCommitted(nodeID: String, amount: UFix64)
    pub event TokensStaked(nodeID: String, amount: UFix64)
    pub event TokensUnStaked(nodeID: String, amount: UFix64)
    pub event StakingAuctionEnded(nodeIDsRemoved: [String])
    pub event RewardsPaid(amount: UFix64)

    /// The minimum amount of tokens that each node type has to stake
    /// in order to be considered valid
    access(contract) var minimumStakeRequired: {UInt8: UFix64}

    /// Conains all the tokens that have been staked or rewarded 
    /// for each node.
    access(contract) var nodeTokenRecords: @{String: NodeTokenRecord}

    /// The total amount of tokens that are staked for all the nodes
    /// of each node type during the current epoch
    access(contract) var totalTokensStakedByNodeType: {UInt8: UFix64}

    /// The total amount of tokens that are paid as rewards every epoch
    pub var weeklyTokenPayout: UFix64

    /// The ratio of the total rewards for each week that goes
    /// to each token type
    access(contract) var rewardRatios: {UInt8: UFix64}

    // Mints Flow tokens for staking rewards
    //access(contract) let flowTokenMinter: @FlowToken.Minter

    /// Resource the holds all the token buckets for a node in the system.
    /// Stored in the `nodeTokenRecords` field in this contract. 
    /// Never leaves the contract
    pub resource NodeTokenRecord {

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

        init(tokensCommitted: @FlowToken.Vault) {
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
            pre {
                FlowStaking.nodeTokenRecords[nodeID] != nil: 
                    "Node with this ID doesn't exist!"
            }

            let nodeTokenRecord <- FlowStaking.getTokenRecord(nodeID)

            /// Add the new tokens to tokens committed
            nodeTokenRecord.tokensCommitted.deposit(from: <-tokens)

            FlowStaking.saveTokenRecord(nodeID, tokenRecord: <-nodeTokenRecord)
        }

        /// Stake tokens that are in the tokensUnlocked bucket 
        /// but haven't been officially staked
        pub fun stakeUnlockedTokens(nodeID: String, amount: UFix64) {
            pre {
                FlowStaking.nodeTokenRecords[nodeID] != nil: 
                    "Node with this ID doesn't exist!"
                FlowStaking.nodeTokenRecords[nodeID]?.tokensUnlocked?.balance! >= amount: 
                    "Not enough unlocked tokens to stake!"
            }

            let nodeTokenRecord <- FlowStaking.getTokenRecord(nodeID)
            
            /// Remove the tokens from the unlocked bucket
            let tokens <- nodeTokenRecord.tokensUnlocked.withdraw(amount: amount)

            /// Add the removed tokens to tokens committed
            nodeTokenRecord.tokensCommitted.deposit(from: <-tokens)

            FlowStaking.saveTokenRecord(nodeID, tokenRecord: <-nodeTokenRecord)
        }

        /// Request amount tokens to be removed from staking
        /// at the end of the next epoch
        pub fun requestUnBonding(nodeID: String, amount: UFix64) {
            pre {
                FlowStaking.nodeTokenRecords[nodeID] != nil: 
                    "Node with this ID doesn't exist!"
                FlowStaking.nodeTokenRecords[nodeID]?.tokensStaked?.balance! + 
                FlowStaking.nodeTokenRecords[nodeID]?.tokensCommitted?.balance! 
                >= amount + FlowStaking.nodeTokenRecords[nodeID]?.tokensRequestedToUnstake!: 
                    "Not enough tokens to unbond!"
            }

            let nodeTokenRecord <- FlowStaking.getTokenRecord(nodeID)

            /// if the request can come from committed, withdraw from committed to unlocked
            if FlowStaking.nodeTokenRecords[nodeID]?.tokensCommitted?.balance! >= amount {

                /// withdraw the requested tokens from committed since they have not been staked yet
                let tokens <- nodeTokenRecord.tokensCommitted.withdraw(amount: amount)

                /// add the withdrawn tokens to tokensUnlocked
                nodeTokenRecord.tokensUnlocked.deposit(from: <-tokens)
            } else {
                /// Get the balance of the tokens that are currently committed
                let amountCommitted = nodeTokenRecord.tokensCommitted.balance

                /// Withdraw all the tokens from the committed field
                let tokens <- nodeTokenRecord.tokensCommitted.withdraw(amount: amountCommitted)

                nodeTokenRecord.tokensUnlocked.deposit(from: <-tokens)

                /// update request to show that leftover amount is requested to be unstaked
                /// at the end of the current epoch
                nodeTokenRecord.tokensRequestedToUnstake = amount - amountCommitted
            }

            FlowStaking.saveTokenRecord(nodeID, tokenRecord: <-nodeTokenRecord)       
        }

        /// Withdraw tokens from the unlocked bucket
        pub fun withdrawUnlockedTokens(nodeID: String, amount: UFix64): @FlowToken.Vault {
            /// remove the tokens from the unlocked bucket
            let tokens <- FlowStaking.nodeTokenRecords[nodeID]?.tokensUnlocked?.withdraw(amount: amount)!

            let flowtokens <- tokens as! @FlowToken.Vault
            return <-flowtokens
        }

    }

    /// Admin resource that has the ability to create new staker objects,
    /// remove insufficiently staked nodes at the end of the staking auction,
    /// and pay rewards to nodes at the end of an epoch
    pub resource StakingAdmin {
        
        /// create a new NodeStaker object to give to an operator that has staked
        pub fun createStaker(_ id: String, nodeTokenRecord: @FlowToken.Vault): @NodeStaker {
            /// Register the staker in the staking contract
            let nodeRecord <- create NodeTokenRecord(tokensCommitted: <-nodeTokenRecord)
            FlowStaking.nodeTokenRecords[id] <-! nodeRecord

            // return their staker object
            return <-create NodeStaker()
        }

        /// Ends the staking auction phase and returns an array of nodes that have insufficient
        /// tokens staked so that the admin of the identity table contract can remove them
        /// from the proposed table
        pub fun endStakingAuction(): [String] {
            var removedNodeIDs: [String] = []

            let proposedNodes = FlowIdentityTable.getAllProposedNodeInfo()

            /// remove nodes that have insufficient stake
            for nodeID in FlowStaking.nodeTokenRecords.keys {

                let nodeTokenRecord <- FlowStaking.getTokenRecord(nodeID)

                /// If the tokens that they have committed for the next epoch
                /// do not meet the minimum requirements
                if (nodeTokenRecord.tokensCommitted.balance + nodeTokenRecord.tokensStaked.balance - nodeTokenRecord.tokensRequestedToUnstake) < FlowStaking.minimumStakeRequired[proposedNodes[nodeID]!.role]! {
                    /// move their committed tokens back to their unlocked tokens
                    nodeTokenRecord.tokensUnlocked.deposit(from: <-nodeTokenRecord.tokensCommitted.withdraw(amount: nodeTokenRecord.tokensCommitted.balance))
                
                    /// Record that their ID needs to be removed from the proposed table
                    removedNodeIDs.append(nodeID)
                }

                FlowStaking.saveTokenRecord(nodeID, tokenRecord: <-nodeTokenRecord)      
            }

            return removedNodeIDs
        }

        /// Called at the end of the epoch to pay rewards to node operators
        pub fun payRewards() {

            /// Get the current list of all the nodes that are operating
            /// during the current epoch
            let currentNodes = FlowIdentityTable.getAllCurrentNodeInfo()

            /// look a every staked node's staked tokens and pay rewards
            /// to their unlocked bucket
            for nodeID in FlowStaking.nodeTokenRecords.keys {

                let nodeTokenRecord <- FlowStaking.getTokenRecord(nodeID)

                /// Calculate the amount of tokens that this node operator receives
                let rewardAmount = FlowStaking.weeklyTokenPayout * FlowStaking.rewardRatios[currentNodes[nodeID]!.role]! * nodeTokenRecord.tokensStaked.balance/FlowStaking.totalTokensStakedByNodeType[currentNodes[nodeID]!.role]! 
                // TODO: DO REAL CALCULATION

                /// Mint the tokens to reward the operator
                let tokensRewarded <- FlowToken.createEmptyVault() //FlowStaking.flowTokenMinter.mintTokens(amount: rewardAmount)
                // TODO: USE THE REAL FLOW TOKEN MINTER

                /// Deposit the tokens into their tokensUnlocked bucket
                nodeTokenRecord.tokensUnlocked.deposit(from: <-tokensRewarded)

                FlowStaking.saveTokenRecord(nodeID, tokenRecord: <-nodeTokenRecord)      
            }
        }

        /// Called at the end of the epoch to move tokens between buckets
        /// for stakers
        /// Tokens that have been committed are moved to the staked bucket
        /// Tokens that were unstaked during the last epoch are fully unlocked
        /// Unstaking requests are filled by moving those tokens from staked to unstaked
        pub fun moveTokens() {
            
            /// Look at each node in the record
            for nodeID in FlowStaking.nodeTokenRecords.keys {

                let nodeTokenRecord <- FlowStaking.getTokenRecord(nodeID)

                nodeTokenRecord.tokensStaked.deposit(from: <-nodeTokenRecord.tokensCommitted.withdraw(amount: nodeTokenRecord.tokensCommitted.balance))
                nodeTokenRecord.tokensUnlocked.deposit(from: <-nodeTokenRecord.tokensUnstaked.withdraw(amount: nodeTokenRecord.tokensUnstaked.balance))
                nodeTokenRecord.tokensUnstaked.deposit(from: <-nodeTokenRecord.tokensStaked.withdraw(amount: nodeTokenRecord.tokensRequestedToUnstake))

                // Reset the tokens requested field so it can be used for the next epoch
                nodeTokenRecord.tokensRequestedToUnstake = 0.0

                FlowStaking.saveTokenRecord(nodeID, tokenRecord: <-nodeTokenRecord)     
            }
        }
    }

    /// Gets the NodeTokenRecord resource for the specified node ID
    access(contract) fun getTokenRecord(_ nodeID: String): @NodeTokenRecord {
        return <- FlowStaking.nodeTokenRecords.remove(key: nodeID)!
    }

    /// Saves the NodeTokenRecord resource for the specified node ID
    access(contract) fun saveTokenRecord(_ nodeID: String, tokenRecord: @NodeTokenRecord) {
        FlowStaking.nodeTokenRecords[nodeID] <-! tokenRecord  
    }

    init() {
        // These are just arbitrary numbers right now
        self.minimumStakeRequired = {UInt8(1): 100.0, UInt8(2): 200.0, UInt8(3): 500.0, UInt8(4): 300.0, UInt8(5): 10.0}
        self.nodeTokenRecords <- {}

        // The preliminary percentage of rewards that go to each node type every epoch
        // subject to change
        self.rewardRatios = {UInt8(1): 0.168, UInt8(2): 0.518, UInt8(3): 0.078, UInt8(4): 0.236, UInt8(5): 0.0}
        self.totalTokensStakedByNodeType = {UInt8(1): 0.0, UInt8(2): 0.0, UInt8(3): 0.0, UInt8(4): 0.0, UInt8(5): 0.0}

        // Arbitrary number for now
        self.weeklyTokenPayout = 250000000.0

        /// Borrow a reference to the Flow Token Admin in the account storage
        // let flowTokenAdmin = self.account.borrow<&FlowToken.Administrator>(from: /storage/flowTokenAdmin)
        //     ?? panic("Could not borrow a reference to the Flow Token Admin resource")

        /// Create a flowTokenMinterResource
        //self.flowTokenMinter <- flowTokenAdmin.createNewMinter(allowedAmount: 100.0)
    }
}
 