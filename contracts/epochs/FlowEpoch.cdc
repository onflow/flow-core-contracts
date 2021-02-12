// import FungibleToken from 0xee82856bf20e2aa6
// import FlowToken from 0x0ae53cb6e3f42a79
// import FlowIDTableStaking from 0x01cf0e2f2f715450
// import FlowEpochClusterQC from 0x03
// import FlowDKG from 0x04

import FungibleToken from 0xFUNGIBLETOKENADDRESS
import FlowToken from 0xFLOWTOKENADDRESS
import FlowIDTableStaking from 0xFLOWIDTABLESTAKINGADDRESS
import FlowEpochClusterQC from 0xQCADDRESS
import FlowDKG from 0xDKGADDRESS

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

pub contract FlowEpoch {

    pub enum EpochPhase: UInt8 {
        pub case STAKINGAUCTION
        pub case EPOCHSETUP
        pub case EPOCHCOMMITTED
    }

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
        nodeInfo: [FlowIDTableStaking.NodeInfo]

        // The first view (inclusive) of the upcoming epoch.
        firstView: UInt64,

        // The last view (inclusive) of the upcoming epoch.
        finalView: UInt64,

        // The cluster assignment for the upcoming epoch. Each element in the list
        // represents one cluster and contains all the node IDs assigned to that
        // cluster, separated by commas.
        collectorClusters: [FlowEpochClusterQC.Cluster],

        // The source of randomness to seed the leader selection algorithm with 
        // for the upcoming epoch.
        randomSource: String,

        // The deadlines of each phase in the DKG protocol to be completed in the upcoming
        // EpochSetup phase. Deadlines are specified in terms of a consensus view number. 
        // When a DKG participant observes a finalized and sealed block with view greater 
        // than the given deadline, it can safely transition to the next phase. 
        DKGPhase1FinalView: UInt64,
        DKGPhase2FinalView: UInt64,
        DKGPhase3FinalView: UInt64
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
        // Group public key is the last element
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
        pub let seed: String

        /// The first view of this epoch
        pub let startView: UInt64

        /// The last view of this epoch
        pub let endView: UInt64

        /// The organization of collector node IDs into clusters
        /// determined by a round robin sorting algorithm
        pub let collectorClusters: [FlowEpochClusterQC.Cluster]

        /// The Quorum Certificates from the ClusterQC contract
        pub var clusterQCs: [String]

        /// The public keys associated with the Distributed Key Generation
        /// process that consensus nodes participate in
        pub var dkgKeys: [String]

        init(counter: UInt64,
             seed: String,
             startView: UInt64,
             endView: UInt64,
             collectorClusters: [FlowEpochClusterQC.Cluster],
             clusterQCs: [String],
             dkgKeys: [String]) {

            self.counter = counter
            self.seed = seed
            self.startView = startView
            self.endView = endView
            self.collectorClusters = collectorClusters
            self.clusterQCs = clusterQCs
            self.dkgKeys = dkgKeys
        }

        pub fun setClusterQCs(qcs: [String]) {
            self.clusterQCs = qcs
        }

        pub fun setDKGGroupKey(keys: [String]) {
            self.dkgKeys = keys
        }
    }

    /// The counter, or ID, of the current epoch
    pub var currentEpochCounter: UInt64

    /// The current phase that the epoch is in
    pub var currentEpochPhase: EpochPhase

    /// The number of views in an entire epoch
    pub var numViewsInEpoch: UInt64

    /// The number of views in the staking auction
    pub var numViewsInStakingAuction: UInt64
    
    /// The number of views in each dkg phase
    pub var numViewsInDKGPhase: UInt64

    /// The number of collector clusters in each epoch
    pub var numCollectorClusters: UInt16

    /// Contains a historical record of the metadata from all previous epochs
    /// indexed by epoch number
    access(contract) var epochMetadata: {UInt64: EpochMetadata}

    access(contract) let QCAdmin: @FlowEpochClusterQC.Admin

    access(contract) let DKGAdmin: @FlowDKG.Admin

    access(contract) let stakingAdmin: @FlowIDTableStaking.Admin

    /// Resource that can update certain some of the contract fields
    pub resource Admin {
        pub fun updateEpochLength(newEpochViews: UInt64) {
            if FlowEpoch.currentEpochPhase != EpochPhase.STAKINGAUCTION {
                return
            }

            FlowEpoch.numViewsInEpoch = newEpochViews
        }

        pub fun updateAuctionLength(newAuctionViews: UInt64) {
            if FlowEpoch.currentEpochPhase != EpochPhase.STAKINGAUCTION {
                return
            }

            FlowEpoch.numViewsInStakingAuction = newAuctionViews
        }

        pub fun updateDKGPhaseLength(newPhaseViews: UInt64) {
            if FlowEpoch.currentEpochPhase != EpochPhase.STAKINGAUCTION {
                return
            }

            FlowEpoch.numViewsInDKGPhase = newPhaseViews
        }

        pub fun updateNumCollectorClusters(newNumClusters: UInt16) {
            if FlowEpoch.currentEpochPhase != EpochPhase.STAKINGAUCTION {
                return
            }

            FlowEpoch.numCollectorClusters = newNumClusters
        }
    }

    pub resource Heartbeat {
        /// Function that is called every block to advance the epoch
        pub fun advanceBlock(randomSource: String?, ) {

            let currentBlock = getCurrentBlock()
            let currentEpochMetadata = FlowEpoch.epochMetadata[FlowEpoch.currentEpochCounter]!

            if FlowEpoch.currentEpochPhase == EpochPhase.STAKINGAUCTION {
                let stakingAuctionFinalView = currentEpochMetadata.startView + FlowEpoch.numViewsInStakingAuction - 1 as UInt64

                if currentBlock.view >= stakingAuctionFinalView {
                    FlowEpoch.endStakingAuction()

                    FlowEpoch.startEpochSetup(randomSource: randomSource!)
                }

            } else if FlowEpoch.currentEpochPhase == EpochPhase.EPOCHSETUP {

                if FlowEpochClusterQC.votingCompleted() && (FlowDKG.dkgCompleted() != nil) {

                    FlowEpoch.endEpochSetup()

                    FlowEpoch.startEpochCommitted()
                }

            } else if FlowEpoch.currentEpochPhase == EpochPhase.EPOCHCOMMITTED {

            }
            
        }
    }

    access(account) fun startNewEpoch() {
        self.stakingAdmin.payRewards()

        self.stakingAdmin.moveTokens()

        self.currentEpochPhase = EpochPhase.STAKINGAUCTION
    }

    access(account) fun endStakingAuction() {
        let ids = FlowIDTableStaking.getProposedNodeIDs()

        let approvedIDs: {String: Bool} = {}
        for id in ids {
            // Here is where we would make sure that each node's 
            // keys and addresses are correct, they haven't committed any violations,
            // and are operating properly
            // for now we just set approved to true for all
            approvedIDs[id] = true
        }

        self.stakingAdmin.endStakingAuction(approvedNodeIDs: approvedIDs)
    }

    /// Starts the EpochSetup phase and emits the epoch setup event
    access(account) fun startEpochSetup(randomSource: String) {
        // Get all the nodes that are proposed for the next epoch
        let ids = FlowIDTableStaking.getProposedNodeIDs()

        // Holds the node Information of all the approved nodes
        var nodeInfoArray: [FlowIDTableStaking.NodeInfo] = []

        // Holds node IDs of only collector nodes
        var collectorNodeIDs: [String] = []

        // Holds node IDs of only consensus nodes for DKG
        var consensusNodeIDs: [String] = []

        for id in ids {
            let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: id)

            nodeInfoArray.append(nodeInfo)

            // If the node is a collector Node, add it to a cluster
            // via a basic round-robin algorithm
            if nodeInfo.role == 1 as UInt8 {
                collectorNodeIDs.append(nodeInfo.id)
            }

            if nodeInfo.role == 2 as UInt8 {
                consensusNodeIDs.append(nodeInfo.id)
            }
        }
        
        let collectorClusters = self.createCollectorClusters(nodeIDs: collectorNodeIDs)

        // Start QC Voting with the supplied clusters
        self.QCAdmin.startVoting(clusters: collectorClusters)

        // Start DKG with the consensus nodes
        self.DKGAdmin.startDKG(nodeIDs: consensusNodeIDs)

        let proposedEpochMetadata = EpochMetadata(counter: self.currentEpochCounter + UInt64(1),
                                                seed: randomSource,
                                                startView: self.epochMetadata[self.currentEpochCounter]!.endView + UInt64(1),
                                                endView: self.epochMetadata[self.currentEpochCounter]!.endView + UInt64(1) + self.numViewsInEpoch,
                                                collectorClusters: collectorClusters,
                                                clusterQCs: [],
                                                dkgKeys: [])

        self.epochMetadata[self.currentEpochCounter + UInt64(1)] = proposedEpochMetadata

        self.currentEpochPhase = EpochPhase.EPOCHSETUP

        emit EpochSetup(counter: proposedEpochMetadata.counter,
                        nodeInfo: nodeInfoArray, 
                        firstView: proposedEpochMetadata.startView,
                        finalView: proposedEpochMetadata.endView,
                        collectorClusters: collectorClusters,
                        randomSource: randomSource,
                        DKGPhase1FinalView: proposedEpochMetadata.startView + self.numViewsInStakingAuction + self.numViewsInDKGPhase,
                        DKGPhase2FinalView: proposedEpochMetadata.startView + self.numViewsInStakingAuction + (2 as UInt64 * self.numViewsInDKGPhase),
                        DKGPhase3FinalView: proposedEpochMetadata.startView + self.numViewsInStakingAuction + (3 as UInt64 * self.numViewsInDKGPhase))

    }

    access(account) fun endEpochSetup() {
        if !FlowEpochClusterQC.votingCompleted() || FlowDKG.dkgCompleted() == nil {
            return
        }

        let clusters = FlowEpochClusterQC.getClusters()

        var clusterQCs: [String] = []

        for cluster in clusters {
            var votes: String = ""

            for vote in cluster.votes {
                if vote.raw! == cluster.votes[0].raw! {
                    votes.concat(vote.raw!)
                } else {
                    votes.concat(",")
                    votes.concat(vote.raw!)
                }
            }
            clusterQCs.append(votes)
        }

        // Get cluster QCs
        self.epochMetadata[self.currentEpochCounter + UInt64(1)]!.setClusterQCs(qcs: clusterQCs)

        // Get DKG result keys
        let dkgKeys = FlowDKG.dkgCompleted()!
        self.epochMetadata[self.currentEpochCounter + UInt64(1)]!.setDKGGroupKey(keys: dkgKeys)

    }

    // Emits the epoch committed event
    access(account) fun startEpochCommitted() {

        self.currentEpochPhase = EpochPhase.EPOCHCOMMITTED

        let dkgKeys = self.epochMetadata[self.currentEpochCounter + UInt64(1)]!.dkgKeys
        let clusterQCs = self.epochMetadata[self.currentEpochCounter + UInt64(1)]!.clusterQCs

        emit EpochCommitted(counter: self.currentEpochCounter + UInt64(1),
                            dkgPubKeys: dkgKeys,
                            clusterQCs: clusterQCs)
        
    }

    /// borrow a reference to the ClusterQCs resource
    access(contract) fun borrowClusterQCAdmin(): &FlowEpochClusterQC.Admin {
        return &self.QCAdmin as! &FlowEpochClusterQC.Admin
    }

    /// borrow a reference to the DKG Admin resource
    access(contract) fun borrowDKGAdmin(): &FlowDKG.Admin {
        return &self.DKGAdmin as! &FlowDKG.Admin
    }

    pub fun getClusterQCVoter(nodeStaker: &FlowIDTableStaking.NodeStaker): @FlowEpochClusterQC.Voter {
        let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeStaker.id)

        assert (
            nodeInfo.role == 1 as UInt8,
            message: "Node operator must be a collector node to get a QC Voter object"
        )

        let clusterQCAdmin = self.borrowClusterQCAdmin()

        return <-clusterQCAdmin.createVoter(nodeID: nodeStaker.id)
    }

    pub fun getDKGParticipant(nodeStaker: &FlowIDTableStaking.NodeStaker): @FlowDKG.Participant {
        let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeStaker.id)

        assert (
            nodeInfo.role == 2 as UInt8,
            message: "Node operator must be a consensus node to get a DKG Participant object"
        )

        let dkgAdmin = self.borrowDKGAdmin()

        return <-dkgAdmin.createParticipant(nodeID: nodeStaker.id)
    }

    pub fun createCollectorClusters(nodeIDs: [String]): [FlowEpochClusterQC.Cluster] {
        var shuffledIDs = self.randomize(nodeIDs)

        // Holds cluster assignments for collector nodes
        let clusters: [FlowEpochClusterQC.Cluster] = []
        var clusterIndex: UInt16 = 0
        let nodeWeightsDictionary: [{String: UInt64}] = []

        for id in shuffledIDs {

            let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: id)

            if nodeWeightsDictionary[clusterIndex] == nil {
                nodeWeightsDictionary[clusterIndex] = {}
            }

            nodeWeightsDictionary[clusterIndex][id] = nodeInfo.initialWeight
            
            // Advance to the next cluster, or back to the first if we have gotten to the last one
            clusterIndex = clusterIndex + 1 as UInt16
            if clusterIndex == self.numCollectorClusters {
                clusterIndex = 0
            }
        }

        // Create the clusters Array that is sent to the QC contract
        // and emitted in the EpochSetup event
        clusterIndex = 0
        while clusterIndex < self.numCollectorClusters {
            clusters.append(FlowEpochClusterQC.Cluster(index: clusterIndex, nodeWeights: nodeWeightsDictionary[clusterIndex]!))
        }

        return clusters

    }
  
    /// A function to generate a random permutation of arr[] 
    /// using the fisher yates shuffling algorithm
    pub fun randomize(_ array: [String]): [String] {  

        var i = array.length - 1

        // Start from the last element and swap one by one. We don't 
        // need to run for the first element that's why i > 0 
        while i > 0
        { 
            // Pick a random index from 0 to i 
            var randomIndex = Int(unsafeRandom()) % (i + 1)
    
            // Swap arr[i] with the element at random index 
            var temp = array[i]
            array[i] = array[randomIndex]
            array[randomIndex] = temp

            i = i - 1
        }

        return array
    } 


    init (numViewsInEpoch: UInt64, 
          numViewsInStakingAuction: UInt64, 
          numViewsInDKGPhase: UInt64, 
          numCollectorClusters: UInt16, 
          randomSource: String,
          collectorClusters: [FlowEpochClusterQC.Cluster]
          dkgPubKeys: [String],
          clusterQCs: [String]) {

        self.currentEpochCounter = 0

        // These values are made up
        self.numViewsInEpoch = numViewsInEpoch
        self.numViewsInStakingAuction = numViewsInStakingAuction
        self.numViewsInDKGPhase = numViewsInDKGPhase
        self.numCollectorClusters = numCollectorClusters
        self.epochMetadata = {}

        let QCAdmin <- self.account.load<@FlowEpochClusterQC.Admin>(from: FlowEpochClusterQC.AdminStoragePath)
            ?? panic("Could not load QC Admin from storage")

        self.QCAdmin <- QCAdmin

        let DKGAdmin <- self.account.load<@FlowDKG.Admin>(from: FlowDKG.AdminStoragePath)
            ?? panic("Could not load DKG Admin from storage")

        self.DKGAdmin <- DKGAdmin

        let stakingAdmin <- self.account.load<@FlowIDTableStaking.Admin>(from: FlowIDTableStaking.StakingAdminStoragePath)
            ?? panic("Could not load staking Admin from storage")

        self.stakingAdmin <- stakingAdmin

        let currentBlock = getCurrentBlock()

        /// Current plan is to not emit service events for bootstrapping
        /// but this will stay here for now until it has been completely finalized

        // ///// Bootstrapping the epoch genesis /////
        // let proposedNodes = FlowIDTableStaking.getProposedNodeIDs()

        // var nodeInfoArray: [FlowIDTableStaking.NodeInfo] = []
        // var collectorClusters: [FlowEpochClusterQC.Cluster] = []

        // for id in proposedNodes {
        //     let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: id)

        //     nodeInfoArray.append(nodeInfo)
        // }

        // let stakingAuctionFinalView = currentBlock.view + self.numViewsInStakingAuction

        // create first collector clusters
        // collectorClusters = createCollectorClusters(nodeIDs: nodeInfoArray)

        // emit epoch setup and epoch committed events for the genesis of epochs
        // emit EpochSetup(counter: self.currentEpochCounter + 1 as UInt64,
        //                 nodeInfo: nodeInfoArray,
        //                 firstView: currentBlock.view + 1 as UInt64,
        //                 finalView: currentBlock.view + self.numViewsInEpoch,
        //                 collectorClusters: collectorClusters,
        //                 randomSource: randomSource,
        //                 DKGPhase1FinalView: stakingAuctionFinalView + self.numViewsInDKGPhase,
        //                 DKGPhase2FinalView: stakingAuctionFinalView + (2 as UInt64 * self.numViewsInDKGPhase),
        //                 DKGPhase3FinalView: stakingAuctionFinalView + (3 as UInt64 * self.numViewsInDKGPhase))


        // emit EpochCommitted(counter: self.currentEpochCounter + 1 as UInt64,
        //                     dkgPubKeys: dkgPubKeys,
        //                     clusterQCs: clusterQCs)

        let firstEpochMetadata = EpochMetadata(counter: self.currentEpochCounter,
                    seed: randomSource,
                    startView: currentBlock.view,
                    endView: currentBlock.view,
                    collectorClusters: [],
                    clusterQCs: [],
                    dkgKeys: [])

        self.epochMetadata[self.currentEpochCounter] = firstEpochMetadata

        let proposedEpochMetadata = EpochMetadata(counter: self.currentEpochCounter,
                    seed: randomSource,
                    startView: firstEpochMetadata.endView + UInt64(1),
                    endView: firstEpochMetadata.endView + self.numViewsInEpoch,
                    collectorClusters: collectorClusters,
                    clusterQCs: clusterQCs,
                    dkgKeys: dkgPubKeys)

        self.epochMetadata[self.currentEpochCounter + UInt64(1)] = proposedEpochMetadata

        self.currentEpochCounter = self.currentEpochCounter + 1 as UInt64

        self.currentEpochPhase = EpochPhase.STAKINGAUCTION
    }

}
