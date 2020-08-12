/*  

    FlowIdentityTable manages the record of the node operators in the Flow network.
    The content in this contract represents the nodes that are operating 
    during the current epoch.

    Admin: The admin has the power to add and remove operators from the record.
    Most of the time, the admin will use the startNewEpoch function 
    to update the entire note table at the beginning of each epoch, 
    The information to update the identity table in this contract
    is determined by the staking smart contract.

*/

pub contract FlowIdentityTable {

    pub event IdentityTableUpdated(currentEpochID: UInt64)

    /// The id of the current epoch
    pub var currentEpochID: UInt64

    /// Holds the identity table for each epoch, indexed by epochID
    /// The proposed identity table for the next epoch is stored
    /// at the index that is currentEpochID + 1
    access(contract) var nodes: {UInt64: {String: Node}}

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
        pub(set) var networkingAddress: String

        /// the public key for networking
        pub(set) var networkingKey: String

        /// the public key for staking
        pub(set) var stakingKey: String

        /// weight as determined by the staking auction
        pub(set) var initialWeight: UInt64

        init(id: String, role: UInt8, networkingAddress: String, networkingKey: String, stakingKey: String, initialWeight: UInt64) {
            pre {
                id.length == 32: "Node ID length must be 32 bytes"
                FlowIdentityTable.nodes[FlowIdentityTable.currentEpochID+UInt64(1)]![id] == nil: "The ID cannot already exist in the proposed record"
                role >= UInt8(1) && role <= UInt8(5): "The role must be 1, 2, 3, 4, or 5"
                networkingAddress.length > 0: "The networkingAddress cannot be empty"
                initialWeight > UInt64(0): "The initial weight must be greater than zero"
            }

            /// Assert that the addresses and keys are not already in use for the proposed nodes
            /// They must be unique
            for node in FlowIdentityTable.nodes[FlowIdentityTable.currentEpochID+UInt64(1)]!.values {
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
            // Remove the proposed epoch table from the record
            let proposedNodeTable = FlowIdentityTable.nodes[FlowIdentityTable.currentEpochID+UInt64(1)]!

            // Remove the node from the table
            proposedNodeTable[newNode.id] = newNode

            // Save the proposed epoch table back to the epoch record
            FlowIdentityTable.nodes[FlowIdentityTable.currentEpochID+UInt64(1)] = proposedNodeTable

        }

        /// Remove a node from the proposed table
        pub fun removeProposedNode(_ nodeID: String): Node? {
            // Remove the proposed epoch table from the record
            let proposedNodeTable = FlowIdentityTable.nodes[FlowIdentityTable.currentEpochID+UInt64(1)]!

            // Remove the node from the table
            let node = proposedNodeTable.remove(key: nodeID)

            // Save the proposed epoch table back to the epoch record
            FlowIdentityTable.nodes[FlowIdentityTable.currentEpochID+UInt64(1)] = proposedNodeTable

            return node
        }

        /// Update the initial weight of one of the proposed nodes
        /// This will be called at the end of the staking auction when all
        /// of the nodes stakes have been finally committed
        pub fun updateInitialWeight(_ nodeID: String, newWeight: UInt64) {
            pre {
                newWeight > UInt64(0): "The initial weight must be greater than zero"
            }
            
            // Remove the node from the table to edit it
            let node = self.removeProposedNode(nodeID)
                ?? panic("Node with the specified ID does not exist!")

            // Set its new initial weight
            node.initialWeight = newWeight

            // Add it back to the table
            self.addProposedNode(node)
        }

        /// The admin doesn't need to have the ability to update the node table
        /// for the current epoch because their info is locked in for the epoch
        /// from the perspective of the smart contract. If they need to be removed
        /// for slashing or something similar, that logic can be handled by the
        /// staking smart contract or the consensus nodes

        /// update the entire node table
        /// This will be called at the beginning of a new epoch
        pub fun startNewEpoch() {
            // set the new proposed epoch to the previous proposed epoch
            FlowIdentityTable.nodes[FlowIdentityTable.currentEpochID+UInt64(2)] = FlowIdentityTable.nodes[FlowIdentityTable.currentEpochID+UInt64(1)]!

            // Update the epoch counter
            FlowIdentityTable.currentEpochID = FlowIdentityTable.currentEpochID + UInt64(1)

            emit IdentityTableUpdated(currentEpochID: FlowIdentityTable.currentEpochID)
            
            /// The proposed nodes for the next epoch are explicitly not changed
            /// because the proposed identity table will stay the same for the next
            /// epoch because we assume most nodes will stay in
        }
    }

    /// Returns the info about all the nodes in the current epoch
    pub fun getAllCurrentNodeInfo(): {String: Node} {
        return FlowIdentityTable.nodes[FlowIdentityTable.currentEpochID]!
    }

    /// Returns the info about all the nodes in the proposed next epoch
    pub fun getAllProposedNodeInfo(): {String: Node} {
        return FlowIdentityTable.nodes[FlowIdentityTable.currentEpochID+UInt64(1)]!
    }

    /// Returns the info about all the nodes in the previous epoch
    pub fun getAllPreviousNodeInfo(): {String: Node} {
        return FlowIdentityTable.nodes[FlowIdentityTable.currentEpochID-UInt64(1)]!
    }

    /// Initialize the node record to be empty
    init(startingEpochID: UInt64) {
        pre {
            startingEpochID > UInt64(0): "Must set the epoch ID as greater than zero"
        }

        self.currentEpochID = 1
        self.nodes = {UInt64(0): {}, UInt64(1): {}, UInt64(2): {}}

        self.account.save(<-create Admin(), to: /storage/flowIdentityTableAdmin)
        self.account.save(<-create Admin(), to: /storage/flowIdentityTableAdmin2)
    }
}
 