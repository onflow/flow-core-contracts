import FungibleToken from 0xee82856bf20e2aa6
import FlowToken from 0x0ae53cb6e3f42a79

import FlowIDTableStaking from 0x01cf0e2f2f715450
import FlowEpochClusterQC from 0x03

// The top-level smart contract managing the lifecycle of epochs. In Flow,
// epochs are the smallest unit of time where the identity table (the set of 
// network operators) is static. Operators may only leave or join the network 
// at epoch boundaries. Operators may be ejected during an epoch for various
// misdemeanours, but they remain in the identity table until the epoch ends.
//
// Epochs are split into 3 phases:
// |==========================================================
// | EPOCH N                                   || EPOCH N+1 ...
// |----- Staking -----|- Setup -|- Committed -|| ...
// |==========================================================
//
// 1)  STAKING PHASE
// Node operators are able to submit staking requests for the NEXT epoch during
// this phase. At the end of this phase, the Epoch smart contract resolves the 
// outstanding staking requests and determines the identity table for the next 
// epoch. The Epoch smart contract emits the EpochSetup service event containing 
// the identity table for the next epoch, which initiates the transition to the 
// Epoch Setup Phase.
//
// 2) SETUP PHASE
// When this phase begins the participants in the next epoch are set. During this
// phase, these participants prepare for the next epoch. In particular, collection
// nodes submit votes for their cluster's root quorum certificate and consensus
// nodes run the distributed key generation protocol (DKG) to set up the random
// beacon. When these preparations are complete, the Epoch smart contract emits the
// EpochCommitted service event containing the artifacts of the set process, which
// initiates the transition to the Epoch Committed Phase.
//
// 3) COMMITTED PHASE
// When this phase begins, the network is fully prepared to transition to the next
// epoch. A failure to enter this phase before transitioning to the next epoch
// indicates that the participants in the next epoch failed to complete the set up
// procedure, which is a critical failure and will cause the chain to halt.
pub contract FlowEpochs {

    // The Epoch Setup service event is emitted when we transition to the Epoch Setup
    // phase. It contains the finalized identity table for the upcoming epoch.
    pub event EpochSetup(
        
        // The counter for the upcoming epoch. Must be one greater than the
        // counter for the current epoch.
        counter: UInt64,

        // Identity table for the upcoming epoch.
        //
        // Conceptually this is [Identity], but needs to be divided into one list
        // for each field in Identity due to Cadence event limitations.
        //
        // Node IDs are hex-encoded 32-byte arrays. Public keys are encoded as
        // by the flow-go crypto library, then hex-encoded.
        nodeIDs: [String],
        nodeRoles: [UInt8],
        nodeStakingPubKeys: [String],
        nodeNetworkPubKeys: [String],
        nodeNetworkAddresses: [String],

        // The last view (inclusive) of the upcoming epoch.
        finalView: UInt64,

        // The cluster assignment for the upcoming epoch. Each element in the list
        // represents one cluster and contains all the node IDs assigned to that
        // cluster, separated by commas.
        collectorClusters: [FlowEpochClusterQC.Cluster],

        // The source of randomness to seed the leader selection algorithm with 
        // for the upcoming epoch.
        randomSource: String
    )

    // The Epoch Committed service event is emitted when we transition from the Epoch
    // Committed phase. It is emitted only when all preparation for the upcoming epoch
    // has been completed
    pub event EpochCommitted(

        // The counter for the upcoming epoch. Must be equal to the counter in the
        // previous EpochSetup event.
        counter: UInt64,

        // The resulting public keys from the DKG process, encoded as by the flow-go
        // crypto library, then hex-encoded.
        // TODO: define ordering
        // TODO: which is group public key
        dkgPubKeys: [String],

        // The result of the QC aggregation process. Each element contains all the votes
        // received for a particular cluster, comma-separated.
        // TODO: define ordering
        clusterQCs: [String]
    )

    pub struct EpochMetadata {

        // The identifier for the epoch
        pub let counter: UInt64

        /// The seed used for generating the epoch setup
        pub let seed: UInt

        /// The first view of this epoch
        pub let startView: UInt64

        /// The last view of this epoch
        pub let endView: UInt64

        /// The organization of collector node IDs into clusters
        /// determined by a round robin sorting algorithm
        pub let collectorClusters: [FlowEpochClusterQC.Cluster]

        /// The Quorum Certificates from the ClusterQC contract
        pub var clusterQCs: Int

        /// The public key associated with the Distributed Key Generation
        /// process that consensus nodes participate in
        pub var dkgGroupKey: String

        init(counter: UInt64,
             seed: UInt,
             startView: UInt64,
             endView: UInt64,
             collectorClusters: [FlowEpochClusterQC.Cluster],
             clusterQCs: Int,
             dkgGroupKey: String) {

            self.counter = counter
            self.seed = seed
            self.startView = startView
            self.endView = endView
            self.collectorClusters = collectorClusters
            self.clusterQCs = clusterQCs
            self.dkgGroupKey = dkgGroupKey
        }
    }

    /// The counter, or ID, of the current epoch
    pub var currentEpochCounter: UInt64

    pub var numViewsinEpoch: UInt64

    /// The number of collector clusters in each epoch
    pub var numCollectorClusters: UInt8

    /// Contains a historical record of the metadata from all previous epochs
    /// indexed by epoch number
    access(contract) var epochMetadata: {UInt64: EpochMetadata}

    access(contract) let QCAdmin: @FlowEpochClusterQC.Admin

    access(account) let stakingAdmin: @FlowIDTableStaking.Admin

    // Emits the epoch setup event
    access(account) fun startEpochSetup() {

    }

    access(account) fun endEpochSetup() {

    }

    // Emits the epoch committed event
    access(account) fun startEpochCommitted() {
        
    }

    access(contract) fun endEpochCommitted() {
        
    }

    // Organizes the collector nodes into clusters
    // via a round robin algorithm
    access(account) fun createCollectorClusters(): [FlowEpochClusterQC.Cluster] {

    }

    /// borrow a reference to the ClusterQCs resource
    access(contract) fun borrowClusterQCAdmin(): &FlowEpochClusterQC.Admin {
        return &FlowEpochs.QCAdmin as! &FlowEpochClusterQC.Admin
    }

    pub fun getClusterQCVoter(nodeStaker: &FlowIDTableStaking.NodeStaker): @FlowEpochClusterQC.Voter {
        let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeStaker.id)

        assert (
            nodeInfo.role == 1,
            message: "Node operator must be a collector node to get a Voter object"
        )

        let clusterQCAdmin = self.borrowClusterQCAdmin()

        return <-clusterQCAdmin.createVoter(nodeID: nodeStaker.id)
    }

    init () {
        self.currentEpochCounter = 0
        self.numViewsinEpoch = 600000
        self.numCollectorClusters = 10
        self.epochMetadata = {}

        let QCAdmin <- self.account.load<@FlowEpochClusterQC.Admin>(from: FlowEpochClusterQC.AdminStoragePath)
            ?? panic("Could not load QC Admin from storage")

        self.QCAdmin <- QCAdmin

        let stakingAdmin <- self.account.load<@FlowIDTableStaking.Admin>(from: FlowIDTableStaking.StakingAdminStoragePath)
            ?? panic("Could not load staking Admin from storage")

        self.stakingAdmin <- stakingAdmin
    }

}