/*  

    FlowIdentityTable manages the record of the node operators in the Flow network.
    The content in this contract represents the nodes that are operating 
    during the current epoch.

    Admin: The admin has the power to add and remove operators from the record.
    Most of the time, the admin will use the addNodeTable function 
    to update the entire note table at the beginning of each epoch, 
    The information to update the identity table in this contract
    is determined by the staking smart contract.

*/

pub contract FlowIdentityTable {

    /// record of nodes in the current epoch
    access(contract) var currentNodes: {String: Node}

    /// record of nodes in the previous epoch
    access(contract) var previousNodes: {String: Node}

    /// record of nodes that are proposed for the next epoch
    access(contract) var proposedNodes: {String: Node}

    /// Contains information that is specific to a node in Flow
    pub struct Node {

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
        pub var networkingAddress: String

        /// the public key for networking
        pub var networkingKey: String

        /// the public key for staking
        pub var stakingKey: String

        /// weight as determined by the staking auction
        pub var initialWeight: UInt64

        init(id: String, role: UInt8, networkingAddress: String, networkingKey: String, stakingKey: String, initialWeight: UInt64) {
            pre {
                id.length == 32: "Node ID length must be 32 bytes"
                FlowIdentityTable.proposedNodes[id] == nil: "The ID cannot already exist in the proposed record"
                role >= UInt8(1) && role <= UInt8(5): "The role must be 1, 2, 3, 4, or 5"
                networkingAddress.length > 0: "The networkingAddress cannot be empty"
                initialWeight > UInt64(0): "The initial weight must be greater than zero"
            }

            /// Assert that the addresses and keys are not already in use for the proposed nodes
            /// They must be unique
            for node in FlowIdentityTable.proposedNodes.values {
                assert (
                    networkingAddress != node.networkingAddress,
                    message: "Networking Address is already in use!"
                )
                assert (
                    networkingKey != node.networkingKey,
                    message: "Networking Key is already in use!"
                )
                assert (
                    stakingKey != node.stakingKey,
                    message: "Staking Key is already in use!"
                )
            }

            self.id = id
            self.role = role
            self.networkingAddress = networkingAddress
            self.networkingKey = networkingKey
            self.stakingKey = stakingKey
            self.initialWeight = initialWeight
        }
    }

    /// Resource for performing special actions for managing the node table
    /// Will live in the Epoch Lifecycle contract so it can perform updates 
    /// of the identity table at the beginning of each epoch
    pub resource Admin {

        /// Add a new node to the proposed table, or update an existing one
        pub fun addProposedNode(_ newNode: Node) {
            FlowIdentityTable.proposedNodes[newNode.id] = newNode
        }

        /// Remove a node from the proposed table
        pub fun removeProposedNode(_ nodeID: String) {
            FlowIdentityTable.proposedNodes.remove(key: nodeID)
        }

        /// The admin doesn't need to have the ability to update the node table
        /// for the current epoch because their info is locked in for the epoch
        /// from the perspective of the smart contract. If they need to be removed
        /// for slashing or something similar, that logic can be handled by the
        /// staking smart contract or the consensus nodes

        /// update the entire node table
        /// This will be called at the beginning of a new epoch
        pub fun updateCurrentNodeTable() {
            /// The current nodes become the previous nodes
            FlowIdentityTable.previousNodes = FlowIdentityTable.currentNodes

            /// The proposed nodes become the current nodes
            FlowIdentityTable.currentNodes = FlowIdentityTable.proposedNodes

            /// The proposed nodes for the next epoch are explicitly not changed
            /// because the proposed identity table will stay the same for the next
            /// epoch because we assume most nodes will stay in
        }
    }

    /// Returns the info about all the nodes in the current epoch
    pub fun getAllCurrentNodeInfo(): {String: Node} {
        return self.currentNodes
    }

    /// Returns the info about all the nodes in the proposed next epoch
    pub fun getAllProposedNodeInfo(): {String: Node} {
        return self.proposedNodes
    }

    /// Returns the info about all the nodes in the previous epoch
    pub fun getAllPreviousNodeInfo(): {String: Node} {
        return self.previousNodes
    }

    /// Initialize the node record to be empty
    init() {
        self.currentNodes = {}
        self.proposedNodes = {}
        self.previousNodes = {}

        self.account.save(<-create Admin(), to: /storage/flowIdentityTableAdmin)
        self.account.save(<-create Admin(), to: /storage/flowIdentityTableAdmin2)
    }
}
 