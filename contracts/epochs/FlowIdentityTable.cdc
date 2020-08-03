/*  

    FlowIdentityTable manages the record of the node operators in the Flow network.
    The content in this contract represents the nodes that are operating 
    during the current epoch.

    Admin: The admin has the power to add and remove operators from the record.
    Most of the time, the admin will use the addNodeTable function 
    to update the entire note table at the beginning of each epoch

*/

import Crypto

pub contract FlowIdentityTable {

    // record of node nodes in the current epoch
    access(contract) var nodes: {UInt32: Node}

    // Contains information that is specific to a node in Flow
    pub struct Node {

        // The unique ID of the node
        // Set when the node is created
        pub let id: UInt32

        // The type of node: Collection, consensus, execution, or verification
        pub var role: Int

        // The address used for networking
        pub var networkingAddress: String

        // the public key for networking
        pub var networkingKey: Crypto.PublicKey

        // the public key for staking
        pub var stakingKey: Crypto.PublicKey

        // weight as determined by the staking auction
        pub var initialWeight: UInt64

        init(id: UInt32, role: Int, networkingAddress: String, networkingKey: Crypto.PublicKey, stakingKey: Crypto.PublicKey, initialWeight: UInt64) {
            pre {
                FlowIdentityTable.nodes[id] == nil: "The ID cannot already exist in the record"
                role >= 1 && role <= 4: "The role must be 1, 2, 3, or 4"
                networkingAddress.length > 0: "The networkingAddress cannot be empty" // TODO: Require exact length
                initialWeight > UInt64(0): "The initial weight must be greater than zero" // TODO: Max weight
            }
            self.id = id
            self.role = role
            self.networkingAddress = networkingAddress
            self.networkingKey = networkingKey
            self.stakingKey = stakingKey
            self.initialWeight = initialWeight
        }
    }

    // Resource for performing special actions for managing the node table
    // Will live in the Epoch Lifecycle contract so it can perform updates 
    // of the identity table at the beginning of each epoch
    pub resource StakeAdmin {

        // admin adds a node to the contract's record
        // this can also be used to modify a node by just adding a node that has
        // already been added, but with new info
        pub fun addNode(_ node: Node) {
            FlowIdentityTable.nodes[node.id] = node
        }

        // admin removes a node from the record
        pub fun removeNode(_ nodeID: UInt32) {
            FlowIdentityTable.nodes.remove(key: nodeID)
        }

        // update the entire node table
        // This will be called at the beginning of a new epoch
        pub fun addNodeTable(_ nodeTable: {UInt32: Node}) {
            FlowIdentityTable.nodes = nodeTable
        }
    }

    // Returns the info about all the nodes in the epoch
    pub fun getAllNodeInfo(): {UInt32: Node} {
        return self.nodes
    }

    // public function to return information about a node operator
    pub fun getNodeInfo(_ id: UInt32): Node? {
        return self.nodes[id]
    }

    // Initialize the node record to be empty
    init() {
        self.nodes = {}
    }
}