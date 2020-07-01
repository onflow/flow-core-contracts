import FungibleToken from 0xee82856bf20e2aa6
import FlowToken from 0x0ae53cb6e3f42a79

/*  FlowRewards manages the record of which addresses have flow tokens staked in the system
    There are two types of stakers in the system, Operators and Delegators

    Operator: Operate one of the four main node types for the network
             Their staked tokens are stored in the main Rewards contract
             in an object that records their node information
             Rewards that are sent to operators are forwarded to their delegator object

    OperatorAccess: Resource that the operator stores in their account 
                    to control their staking. It can be used to stake, unstake,
                    deposit awards, and add a delegator to receive rewards

    Delegator: A Flow account that delegates an amount of Flow tokens
              to an operator creates a delegator resource object
              that is stored in the central contract. It holds their delegated tokens
              and indicates which operator they are delegating to.
              Rewarded tokens go to this object and are stored in a temporary
              rewards bucket. If a delegator wants to withdraw
              their delegation or stake more tokens, they must wait until the end of the epoch for
              their request to be confirmed.

    DelegatorAccess: Resource that the delegator stores in their account that allows
                     them to perform actions to manage their delegation, including registering
                     to delegate to an operator, delegate more tokens, request that their delegated
                     tokens be moved, and withdraw awarded tokens.

    Admin: The admin has the power to add and remove operators from the record.
           They also have the authority to payout rewards to stakers
           by minting flow tokens that are divided up between the nodes.

    When a payout happens, the total reward is divided into four buckets
    that represent each node type. Then the total number of rewards
    for each type is divided by the total number of flow tokens staked by
    all the operators and delegators for that node type to get the unit reward
    for each staked Flow token. That unit reward is multiplied by each stakers
    amount of staked tokens and the total is sent to them.

    In the case of a delegator, the delegator receives 90% of its rewards and 
    10% of the rewards go to the operator that has been delegated to.
        
    After the rewards have been sent, the epoch moves delegated tokens around
    within each delegation position to reflect the delegators desires to 
    stake or withdraw more tokens.

*/

pub contract FlowRewards {

    // contains information specific to the four node types
    // 1 = Collection
    // 2 = Consensus
    // 3 = Execution
    // 4 = Verification
    access(contract) let nodeInfo: {Int: Node}

    // record of node operators
    access(contract) let operators: @{Address: Operator}

    // record of delegators 
    access(contract) let delegators: @{Address: [Delegator]}

    // the total combined payout that goes to all nodes each week
    pub var weeklyTokenPayout: UFix64

    // portion of a delegator's rewards that they get
    // default to .90, or 90%
    pub var delegatorRewardPortion: UFix64

    // portion of a delegator's rewards that their operator gets
    // default to .10, or 10%
    pub var operatorRewardPortion: UFix64

    // Contains information that is specific to a node type in Flow
    pub struct Node {

        // The type of node
        pub let name: String

        // total flow tokens that has been staked by all stakers for this type
        access(contract) var totalAmountStaked: UFix64

        // the percentage of the reward that is allocated to each node type
        // it is a ratio, so it must be >= 0 and <= 1
        pub var rewardRatio: UFix64

        // The minimum stake that a node must have
        pub var requiredStake: UFix64

        init(name: String, rewardRatio: UFix64, requiredStake: UFix64) {
            pre {
                rewardRatio >= 0.0 && rewardRatio <= 1.0
            }
            self.name = name
            self.totalAmountStaked = 0.0
            self.rewardRatio = rewardRatio
            self.requiredStake = requiredStake
        }

        pub fun rewardUnit(): UFix64 {
            return FlowRewards.weeklyTokenPayout / self.totalAmountStaked
        }

        pub fun updateTotalAmountStaked(_ newAmount: UFix64) {
            self.totalAmountStaked = newAmount
        }
    }

    // Resource object that represents a node operator
    //
    pub resource Operator: FungibleToken.Receiver {

        // indicates what kind of node this operator has
        // 1 = Collection
        // 2 = Consensus
        // 3 = Execution
        // 4 = Verification
        pub var nodeType: Int

        // The delegator where this operator receives its staking rewards
        pub(set) var delegator: Capability?

        // The amount of tokens that this operator has staked
        pub var tokensStaked: @FlowToken.Vault

        init(nodeType: Int, stakingTokens: @FlowToken.Vault) {
            pre {
                nodeType >= 1 && nodeType <= 4: "The node type must be 1, 2, 3, or 4"
                stakingTokens.balance == FlowRewards.nodeInfo[nodeType]!.requiredStake: "Staked tokens must equal the minimum staking balance for the node type"
            }
            self.nodeType = nodeType
            self.delegator = nil
            self.tokensStaked <- stakingTokens
        }

        destroy() {
            destroy self.tokensStaked
        }

        pub fun deposit(from: @FungibleToken.Vault) {
            self.tokensStaked.deposit(from: <-from)
        }
    }

    // resource that a node operator stores in their account
    // to interact with their node and staking information
    pub resource OperatorAccess: FungibleToken.Receiver {
        
        // Add a delegator to this operator object to receive token rewards
        pub fun addDelegator(delegator: Capability) {
            pre {
                delegator.borrow<&DelegatorAccess>() != nil: "delegator capability does not match the correct interface"
            }
            let operator <- self.loadOperator()

            // set the operatora delegator for rewards
            operator.delegator = delegator

            // save the operator back to the contract storage
            self.storeOperator(<-operator)
        }

        // directly add tokens to the tokens that are staked
        pub fun stakeTokens(from: @FungibleToken.Vault) {
            let operator <- self.loadOperator()

            // deposit tokens into the staked tokens vault for the operator
            operator.deposit(from: <-from)

            self.storeOperator(<-operator)
        }

        // directly unstake tokens for this operator
        pub fun unstakeTokens(amount: UFix64): @FungibleToken.Vault {
            let operator <- self.loadOperator()

            if operator.tokensStaked.balance - amount < FlowRewards.nodeInfo[operator.nodeType]!.requiredStake {
                panic("Cannot unstake less than the required amount!")
            }

            let unstakedTokens <- operator.tokensStaked.withdraw(amount: amount)

            self.storeOperator(<-operator)

            return <-unstakedTokens
        }

        // Generic deposit function to deposit the rewards for this operator
        // Forwards the deposited tokens to the delegator
        pub fun deposit(from: @FungibleToken.Vault) {

            let operator <- self.loadOperator()

            let delegatorRef = operator.delegator!.borrow<&DelegatorAccess>()!

            let ownerAddress = self.owner!.address
            delegatorRef.award(operator: ownerAddress, from: <-from)

            self.storeOperator(<-operator)
        }

        // Load the operator object from the contract storage
        access(self) fun loadOperator(): @Operator {
            let ownerAddress = self.owner!.address

            return <- FlowRewards.operators.remove(key: ownerAddress)!
        }

        // store the operator object into the contract storage
        access(self) fun storeOperator(_ operator: @Operator) {
            let ownerAddress = self.owner!.address
            FlowRewards.operators[ownerAddress] <-! operator
        }
    }

    // Object the Delegator hold to record their tokens
    pub resource Delegator: FungibleToken.Receiver {

        // indicates the staker that this delegator has delegated tokens to
        pub(set) var operator: Address

        // tokens that are locked for staking delegation
        // These are the tokens that accrue rewards
        pub var tokensLocked: @FlowToken.Vault

        // tokens that have been awarded pending to be added to the delegation
        pub var tokensAwarded: @FlowToken.Vault

        // tokens that are pending withdrawal from the delegator
        // they do not affect staking 
        pub var tokensPending: @FlowToken.Vault

        // tokens that are available for withdrawal
        pub var tokensUnlocked: @FlowToken.Vault

        // Shows the requested movement of funds in the stakers
        // account
        pub(set) var requestedMovement: Fix64

        init(operator: Address) {
            pre {
                FlowRewards.operators[operator] != nil: "Operator must be valid"
            }
            self.operator = operator
            self.tokensLocked <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.tokensAwarded <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.tokensPending <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.tokensUnlocked <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            self.requestedMovement = 0.0
        }

        destroy() {
            // Send the remaining tokens that have been delegated to the operator 
            // that was delegated to
            let operator <- FlowRewards.operators.remove(key: self.operator)!
            operator.deposit(from: <-self.tokensLocked)
            operator.deposit(from: <-self.tokensAwarded)
            operator.deposit(from: <-self.tokensPending)
            operator.deposit(from: <-self.tokensUnlocked)
            FlowRewards.operators[self.operator] <-! operator
        }

        // Deposit tokens to the tokensAwarded Vault. This is used by rewards
        // so that recently rewarded tokens don't count towards staking until 
        // a week has passed
        pub fun deposit(from: @FungibleToken.Vault) {
            // deposit new delegation tokens to tokensAwarded
            self.tokensAwarded.deposit(from: <-from)
        }

        // only the StakeRecord resource can call this function
        // This function moves tokens between different vaults in order
        // to ensure they are in the places that the owner has indicated
        access(contract) fun moveTokens() {

            // Get the node type for the operator that this delegator uses
            let nodeType = FlowRewards.operators[self.operator]?.nodeType!

            // deposit all the tokens from tokensPending to tokensUnlocked because
            // they were marked for withdrawal the week before
            self.tokensUnlocked.deposit(from: <-self.tokensPending.withdraw(amount: self.tokensPending.balance))

            // If the delegator wanted to add tokens
            if self.requestedMovement > Fix64(0.0) {

                // move the requested amount from the unlocked bucket to the awarded bucket
                self.tokensAwarded.deposit(from: <-self.tokensUnlocked.withdraw(amount: UFix64(self.requestedMovement)))

            // If the delegator wanted to remove tokens from delegation
            } else if self.requestedMovement < Fix64(0.0) {

                // withdraw those tokens from the delegated bucket
                let unDelegatedTokens <- self.tokensLocked.withdraw(amount: UFix64(Fix64(0.0) - self.requestedMovement))

                // ensure that this subtraction is reflected in the amount staked per node type
                FlowRewards.nodeInfo[nodeType]!.updateTotalAmountStaked(FlowRewards.nodeInfo[nodeType]!.totalAmountStaked - unDelegatedTokens.balance)

                // deposit it in the tokens that are pending withdrawal
                self.tokensPending.deposit(from: <-unDelegatedTokens)
            }

            // get the tokens that have been awarded since the last payout
            let newDelegatedTokens <- self.tokensAwarded.withdraw(amount: self.tokensAwarded.balance)

            // update the staking record
            FlowRewards.nodeInfo[nodeType]!.updateTotalAmountStaked(FlowRewards.nodeInfo[nodeType]!.totalAmountStaked - newDelegatedTokens.balance)

            // deposit the awarded tokens into the locked delegated tokens bucket
            self.tokensLocked.deposit(from: <-newDelegatedTokens)
        }

        // Get the type of the node that this delegates tokens to
        pub fun getNodeType(): Int {
            return FlowRewards.operators[self.operator]?.nodeType!
        }
    }

    // Resource that lives in the delegators account to allow them to 
    // move tokens in their delegation resource in the central account
    //
    pub resource DelegatorAccess {

        // registers the delegator in the Rewards smart contract
        pub fun registerDelegator(operator: Address) {
            if let delegator <- self.loadDelegator(operator) {
                self.saveDelegator(operator: operator, delegator: <-delegator)
            } else {
                self.saveDelegator(operator: operator, delegator: <-create Delegator(operator: operator))
            }
        }

        // update the amount that has been requested to be moved 
        // in or out of delegation
        pub fun requestMovement(operator: Address, amount: Fix64) {
            let delegator <- self.loadDelegator(operator)
                ?? panic("Could not load the delegator for the specified node operator")

            if delegator.requestedMovement == Fix64(0.0) || 
                (delegator.requestedMovement < Fix64(0) && (Fix64(0.0) - delegator.requestedMovement) <= Fix64(delegator.tokensLocked.balance)) || 
                (delegator.requestedMovement > Fix64(0) && delegator.requestedMovement <= Fix64(delegator.tokensUnlocked.balance)) {
            } else {
                delegator.requestedMovement + amount
            }

            self.saveDelegator(operator: operator, delegator: <-delegator)
        }

        // withdraw the tokens that are unlocked and allowed to with withdrawn
        pub fun withdrawUnlockedTokens(operator: Address, amount: UFix64): @FungibleToken.Vault? {
            let delegator <- self.loadDelegator(operator)
                ?? panic("Could not load the delegator for the specified node operator")

            // withdraw amount tokens from tokensUnlocked
            let unlockedTokens <-delegator.tokensUnlocked.withdraw(amount: amount)

            self.saveDelegator(operator: operator, delegator: <-delegator)

            return <-unlockedTokens

        }

        // award tokens to the tokensAwarded Vault. This is used by rewards
        // so that recently rewarded tokens don't count towards staking until 
        // a week has passed
        pub fun award(operator: Address, from: @FungibleToken.Vault) {
            let delegator <- self.loadDelegator(operator)
                ?? panic("Could not load the delegator for the specified node operator")
            
            // deposit new delegation tokens to tokensAwarded
            delegator.tokensAwarded.deposit(from: <-from)

            self.saveDelegator(operator: operator, delegator: <-delegator)

        }

        // directly delegate tokens to the locked Vault. Can be called any time
        pub fun directlyDelegateTokens(operator: Address, from: @FungibleToken.Vault) {
            let nodeType = FlowRewards.operators[operator]?.nodeType!

            let delegator <- self.loadDelegator(operator)
                ?? panic("Could not load the delegator for the specified node operator")

            FlowRewards.nodeInfo[nodeType]!.updateTotalAmountStaked(FlowRewards.nodeInfo[nodeType]!.totalAmountStaked + from.balance)

            delegator.tokensLocked.deposit(from: <-from)

            self.saveDelegator(operator: operator, delegator: <-delegator)

        }

        // loads the delegator object from the contract storage
        // returns nil if there is no delegator for the specified operator
        access(self) fun loadDelegator(_ operator: Address): @Delegator? {
            let nodeType = FlowRewards.operators[operator]?.nodeType!

            let delegatorAddr = self.owner!.address

            if let delegators <- FlowRewards.delegators.remove(key: delegatorAddr) {

                var i = 0

                while i < delegators.length {
                    if operator == delegators[i].operator {
                        let delegator <- delegators.remove(at: i)
                        FlowRewards.delegators[delegatorAddr] <-! delegators
                        return <-delegator
                    }
                    i = i + 1
                }
                FlowRewards.delegators[delegatorAddr] <-! delegators
            }
            return nil
        }

        // saves the delegator object to the contract storage
        access(self) fun saveDelegator(operator: Address, delegator: @Delegator) {
            let nodeType = FlowRewards.operators[operator]?.nodeType!

            let delegatorAddr = self.owner!.address

            let delegators <- FlowRewards.delegators.remove(key: delegatorAddr)!
            
            delegators.append(<-delegator)
            
            FlowRewards.delegators[delegatorAddr] <-! delegators
        }
    }

    // Resource for performing special actions like 
    // paying rewards and managing delegator token movements 
    pub resource StakeAdmin {

        // gives the staking admin access to the flow minter so
        // it can mint rewards to the flow stakers
        pub var flowMinter: Capability?

        init() {
            self.flowMinter = nil
        }

        // admin adds an operator to the contract's record
        pub fun addOperator(_ operatorAddr: Address, operator: @Operator) {
            pre {
                FlowRewards.operators[operatorAddr] == nil: "The specified operator address is already in use"
            }

            // Add the operator's staked tokens to the balance staked for that node type
            FlowRewards.nodeInfo[operator.nodeType]!.updateTotalAmountStaked(FlowRewards.nodeInfo[operator.nodeType]!.totalAmountStaked + operator.tokensStaked.balance)

            // Save it to the operator record
            FlowRewards.operators[operatorAddr] <-! operator

        }

        // admin removes an operator from the record
        pub fun removeOperator(_ operator: Address) {

            // remove the operator from the record if it exists there
            let operator <- FlowRewards.operators.remove(key: operator) ?? nil

            // If the operator existed, subtract its stake from the amount staked for that node type
            // and then destroy the operator
            if let operator <- operator {

                FlowRewards.nodeInfo[operator.nodeType]!.updateTotalAmountStaked(FlowRewards.nodeInfo[operator.nodeType]!.totalAmountStaked - operator.tokensStaked.balance)

                destroy operator
            } else {
                // if it didn't exist, simple destroy the optional and return
                destroy operator
            }
        }

        // marks the end of an epoch
        // payouts to stakers and delegators happen
        // and delegator's token positions are updated
        pub fun epochPayout() {
            pre {
                self.flowMinter?.borrow<&FlowToken.Minter>() != nil: "Minter is not stored in the admin resource"
            }

            // borrow a reference to the flow token minter
            let minter = self.flowMinter!.borrow<&FlowToken.Minter>()!

            // Mint all the tokens to be minted for the week
            let payoutTokens <- minter.mintTokens(amount: FlowRewards.weeklyTokenPayout)

            for operatorAddress in FlowRewards.operators.keys {
                let operator <- FlowRewards.operators.remove(key: operatorAddress)!

                // calculate the reward for this specific node operator by multiplying the
                // reward unit by all the tokens that they have staked
                let operatorRewardAmount = FlowRewards.nodeInfo[operator.nodeType]!.rewardUnit() * operator.tokensStaked.balance

                // send the rewards to the node operator
                operator.deposit(from: <-payoutTokens.withdraw(amount: operatorRewardAmount))

                // ensure the operator is saved back to the record
                FlowRewards.operators[operatorAddress] <-! operator
            }

            // after paying all the operators, iterate through all the 
            // delegators to pay them their rewards
            // and approve the movement between buckets at each epoch
            for delegatorAddress in FlowRewards.delegators.keys {

                // borrow a reference to the current delegator
                let delegators <- FlowRewards.delegators.remove(key: delegatorAddress)!

                var i = 0
                while i < delegators.length {

                    // Get the operator that this node delegates to
                    let operator <- FlowRewards.operators.remove(key: delegators[i].operator)!

                    // Calculate the total rewards that are allocated for this delegator
                    // by multiplying (rewards per 1 staked token) * (number of staked tokens)
                    let totalRewardsForDelegator = FlowRewards.nodeInfo[operator.nodeType]!.rewardUnit() * delegators[i].tokensLocked.balance

                    // Calculate the 10% cut that the operator receives from the delegator
                    let operatorRewardAmount = totalRewardsForDelegator * FlowRewards.operatorRewardPortion

                    // send the operator's cut 
                    operator.deposit(from: <-payoutTokens.withdraw(amount: operatorRewardAmount))

                    // save the operator back to the contract
                    FlowRewards.operators[delegators[i].operator] <-! operator

                    // Calculate the 90% cut that the delegator receives
                    let delegatorRewardAmount = totalRewardsForDelegator * FlowRewards.delegatorRewardPortion
                    
                    // send the delegator's cut
                    delegators[i].deposit(from: <-payoutTokens.withdraw(amount: delegatorRewardAmount))

                    // perform required end of epoch token movements for the delegator
                    delegators[i].moveTokens()

                    i = i + 1
                }

                FlowRewards.delegators[delegatorAddress] <-! delegators
            }

            if payoutTokens.balance > 0.0 {
                panic("there are still payout tokens left")
            }
            destroy payoutTokens
        }

        // Add the flowtoken minter capability to the resource
        pub fun addMinter(_ flowMinter: Capability) {
            pre {
                flowMinter.borrow<&FlowToken.Minter>() != nil: "Invalid Flow Minter"
            }

            self.flowMinter = flowMinter
        }

        // creates an Operator resource 
        pub fun createOperator(nodeType: Int, stakingTokens: @FlowToken.Vault): @Operator {
            return <- create Operator(nodeType: nodeType, stakingTokens: <-stakingTokens)
        }
    }

    // Creates a new Delegator resource to give
    // to a delegator
    pub fun createDelegator(delegatee: Address): @Delegator {
        return <- create Delegator(operator: delegatee)
    }

    init() {
        self.operators <- {}
        self.delegators <- {}

        self.weeklyTokenPayout = 250000000.0

        self.nodeInfo = {1: Node(name: "Collection", rewardRatio: 0.168, requiredStake: 50.0),
                         2: Node(name: "Consensus", rewardRatio: 0.518, requiredStake: 100.0),
                         3: Node(name: "Execution", rewardRatio: 0.078, requiredStake: 500.0),
                         4: Node(name: "Verification", rewardRatio: 0.236, requiredStake: 200.0)}

        self.delegatorRewardPortion = 0.9

        self.operatorRewardPortion = 0.1
    }
}