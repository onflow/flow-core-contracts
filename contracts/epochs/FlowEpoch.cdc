import "FungibleToken"
import "FlowToken"
import "FlowIDTableStaking"
import "FlowClusterQC"
import "FlowDKG"
import "FlowFees"

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
// EpochCommit service event containing the artifacts of the set process, which
// initiates the transition to the Epoch Commit Phase.
//
// 3) COMMITTED PHASE
// When this phase begins, the network is fully prepared to transition to the next
// epoch. A failure to enter this phase before transitioning to the next epoch
// indicates that the participants in the next epoch failed to complete the set up
// procedure, which is a critical failure and will cause the chain to halt.

access(all) contract FlowEpoch {

    access(all) enum EpochPhase: UInt8 {
        access(all) case STAKINGAUCTION
        access(all) case EPOCHSETUP
        access(all) case EPOCHCOMMIT
    }

    access(all) enum NodeRole: UInt8 {
        access(all) case NONE
        access(all) case Collector
        access(all) case Consensus
        access(all) case Execution
        access(all) case Verification
        access(all) case Access
    }

    /// The Epoch Start service event is emitted when the contract transitions
    /// to a new epoch in the staking auction phase.
    access(all) event EpochStart (

        /// The counter for the current epoch that is beginning
        counter: UInt64,

        /// The first view (inclusive) of the current epoch.
        firstView: UInt64,

        /// The last view (inclusive) of the current epoch's staking auction.
        stakingAuctionEndView: UInt64,

        /// The last view (inclusive) of the current epoch.
        finalView: UInt64,

        /// Total FLOW staked by all nodes and delegators for the current epoch.
        totalStaked: UFix64,

        /// Total supply of all FLOW for the current epoch
        /// Includes the rewards that will be paid for the previous epoch
        totalFlowSupply: UFix64,

        /// The total rewards that will be paid out at the end of the current epoch.
        totalRewards: UFix64,
    )

    /// The Epoch Setup service event is emitted when we transition to the Epoch Setup
    /// phase. It contains the finalized identity table for the upcoming epoch.
    access(all) event EpochSetup(

        /// The counter for the upcoming epoch. Must be one greater than the
        /// counter for the current epoch.
        counter: UInt64,

        /// Identity table for the upcoming epoch with all node information.
        /// Includes:
        /// nodeID, staking key, networking key, networking address, role,
        /// staking information, weight, and more.
        nodeInfo: [FlowIDTableStaking.NodeInfo],

        /// The first view (inclusive) of the upcoming epoch.
        firstView: UInt64,

        /// The last view (inclusive) of the upcoming epoch.
        finalView: UInt64,

        /// The cluster assignment for the upcoming epoch. Each element in the list
        /// represents one cluster and contains all the node IDs assigned to that
        /// cluster, with their weights and votes
        collectorClusters: [FlowClusterQC.Cluster],

        /// The source of randomness to seed the leader selection algorithm with
        /// for the upcoming epoch.
        randomSource: String,

        /// The deadlines of each phase in the DKG protocol to be completed in the upcoming
        /// EpochSetup phase. Deadlines are specified in terms of a consensus view number.
        /// When a DKG participant observes a finalized and sealed block with view greater
        /// than the given deadline, it can safely transition to the next phase.
        DKGPhase1FinalView: UInt64,
        DKGPhase2FinalView: UInt64,
        DKGPhase3FinalView: UInt64,

        /// The target duration for the upcoming epoch, in seconds
        targetDuration: UInt64,
        /// The target end time for the upcoming epoch, specified in second-precision Unix time
        targetEndTime: UInt64
    )

    /// The EpochCommit service event is emitted when we transition from the Epoch
    /// Committed phase. It is emitted only when all preparation for the upcoming epoch
    /// has been completed
    access(all) event EpochCommit (

        /// The counter for the upcoming epoch. Must be equal to the counter in the
        /// previous EpochSetup event.
        counter: UInt64,

        /// The result of the QC aggregation process. Each element contains
        /// all the nodes and votes received for a particular cluster
        /// QC stands for quorum certificate that each cluster generates.
        clusterQCs: [FlowClusterQC.ClusterQC],

        /// The resulting public keys from the DKG process, encoded as by the flow-go
        /// crypto library, then hex-encoded.
        /// Group public key is the first element, followed by the individual keys
        dkgPubKeys: [String],

        dkgGroupKey: String,

        dkgIdMapping: {String: Int},
    )

    /// The EpochRecover service event is emitted via the recoverEpoch governance transaction to execute an epoch recovery.
    /// The epoch recovery process is used if the Epoch Preparation Protocol fails for any reason.
    /// When this happens, the network enters Epoch Fallback Mode [EFM], wherein the Protocol State
    /// extends the current epoch until an epoch recovery can take place. In general, while in EFM, the
    /// Protocol State and the FlowEpoch smart contract may have conflicting views about the current
    /// valid epoch state (epoch counter and phase). The epoch recovery process resolves this inconsistency
    /// by injecting a new common shared state to proceed forward from. 
    /// Concretely, the epoch recovery process fully specifies the parameters for a new epoch to transition into
    /// (essentially all fields of the EpochSetup and EpochCommit events), called the recovery epoch.
    /// The FlowEpoch smart contracts inserts the recovery epoch, starts it, and emits the EpochRecover event,
    /// which contains the same data. When the EpochRecover event is processed by the protocol state, 
    /// the Protocol State is updated to include the recovery epoch as well.
    access(all) event EpochRecover (
        /// The counter for the RecoveryEpoch.
        /// This must be 1 greater than the current epoch counter, as reported by the Protocol State,
        /// otherwise the EpochRecover event will be rejected (recovery process will fail).
        counter: UInt64,

        /// Identity table for the upcoming epoch with all node information.
        /// including nodeID, staking key, networking key, networking address, role,
        /// staking information, weight, and more.
        nodeInfo: [FlowIDTableStaking.NodeInfo],

        /// The first view (inclusive) of the RecoveryEpoch. This must be 1 greater
        /// than the current epoch's final view, as reported by the Protocol State,
        /// otherwise the EpochRecover event will be rejected (recovery process will fail).
        firstView: UInt64,

        /// The last view (inclusive) of the RecoveryEpoch.
        finalView: UInt64,

        /// The collector node cluster assignment for the RecoveryEpoch. Each element in the list
        /// represents one cluster and contains all the node IDs assigned to that cluster.
        clusterAssignments: [[String]],

        /// The source of randomness to seed the leader selection algorithm with
        /// for the upcoming epoch.
        randomSource: String,

        /// The deadlines of each phase in the DKG protocol to be completed in the upcoming
        /// EpochSetup phase. Deadlines are specified in terms of a consensus view number.
        /// When a DKG participant observes a finalized and sealed block with view greater
        /// than the given deadline, it can safely transition to the next phase.
        DKGPhase1FinalView: UInt64,
        DKGPhase2FinalView: UInt64,
        DKGPhase3FinalView: UInt64,

        /// The target duration for the upcoming epoch, in seconds
        targetDuration: UInt64,
        /// The target end time for the upcoming epoch, specified in second-precision Unix time
        targetEndTime: UInt64,

        /// The cluster QCs passed in the recoverEpoch transaction. These are generated out-of-band
        /// using the same procedure as during a spork.
        /// CAUTION: Validity of the QCs is not explicitly verified during the recovery process. An
        /// invalid cluster QC will prevent the respective cluster from starting its local consensus
        /// and hence prevent it from functioning for the entire epoch. If all cluster QCs are invalid,
        /// the blockchain cannot ingest transactions, which can only be resolved through a spork!
        clusterQCVoteData: [FlowClusterQC.ClusterQCVoteData],

        /// The DKG public keys and ID mapping for the recovery epoch. 
        /// Currently, these are re-used from the last successful DKG.
        /// CAUTION: Validity of the key vector is not explicitly verified during the recovery process.
        /// Invalid DKG information has the potential to prevent Flow's main consensus from continuing,
        /// which would halt the chain for good and can only be resolved through a spork.

        dkgPubKeys: [String],
        dkgGroupKey: String,
        dkgIdMapping: {String: Int},
    )

    /// Contains specific metadata about a particular epoch
    /// All historical epoch metadata is stored permanently
    access(all) struct EpochMetadata {

        /// The identifier for the epoch
        access(all) let counter: UInt64

        /// The seed used for generating the epoch setup
        access(all) let seed: String

        /// The first view of this epoch
        access(all) let startView: UInt64

        /// The last view of this epoch
        access(all) let endView: UInt64

        /// The last view of the staking auction
        access(all) let stakingEndView: UInt64

        /// The total rewards that are paid out for the epoch
        access(all) var totalRewards: UFix64

        /// The reward amounts that are paid to each individual node and its delegators
        access(all) var rewardAmounts: [FlowIDTableStaking.RewardsBreakdown]

        /// Tracks if rewards have been paid for this epoch
        access(all) var rewardsPaid: Bool

        /// The organization of collector node IDs into clusters
        /// determined by a round robin sorting algorithm
        access(all) let collectorClusters: [FlowClusterQC.Cluster]

        /// The Quorum Certificates from the ClusterQC contract
        access(all) var clusterQCs: [FlowClusterQC.ClusterQC]

        /// The public keys associated with the Distributed Key Generation
        /// process that consensus nodes participate in
        /// The first element is the group public key, followed by n participant public keys.
        /// NOTE: This data structure was updated to include a mapping from node ID to DKG index.
        /// Because structures cannot be updated in Cadence, we include the groupPubKey and pubKeys
        /// fields here (idMapping field is omitted).
        access(all) var dkgKeys: [String]

        init(counter: UInt64,
             seed: String,
             startView: UInt64,
             endView: UInt64,
             stakingEndView: UInt64,
             totalRewards: UFix64,
             collectorClusters: [FlowClusterQC.Cluster],
             clusterQCs: [FlowClusterQC.ClusterQC],
             dkgKeys: [String]) {

            self.counter = counter
            self.seed = seed
            self.startView = startView
            self.endView = endView
            self.stakingEndView = stakingEndView
            self.totalRewards = totalRewards
            self.rewardAmounts = []
            self.rewardsPaid = false
            self.collectorClusters = collectorClusters
            self.clusterQCs = clusterQCs
            self.dkgKeys = dkgKeys
        }

        access(account) fun copy(): EpochMetadata {
            return self
        }

        access(account) fun setTotalRewards(_ newRewards: UFix64) {
            self.totalRewards = newRewards
        }

        access(account) fun setRewardAmounts(_ rewardBreakdown: [FlowIDTableStaking.RewardsBreakdown]) {
            self.rewardAmounts = rewardBreakdown
        }

        access(account) fun setRewardsPaid(_ rewardsPaid: Bool) {
            self.rewardsPaid = rewardsPaid
        }

        access(account) fun setClusterQCs(qcs: [FlowClusterQC.ClusterQC]) {
            self.clusterQCs = qcs
        }

        /// Sets the DKG group key (keys[0]) and participant keys (keys[1:]) from the DKG result.
        /// NOTE: This data structure was updated to include a mapping from node ID to DKG index.
        /// Because structures cannot be updated in Cadence, we include the groupPubKey and pubKeys
        /// fields here (idMapping field is omitted).
        access(account) fun setDKGKeys(keys: [String]) {
            self.dkgKeys = keys
        }
    }

    /// Metadata that is managed and can be changed by the Admin
    access(all) struct Config {
        /// The number of views in an entire epoch
        access(all) var numViewsInEpoch: UInt64

        access(all) fun setNumViewsInEpoch(_ views: UInt64) {
            self.numViewsInEpoch = views
        }

        /// The number of views in the staking auction
        access(all) var numViewsInStakingAuction: UInt64

        access(all) fun setNumViewsInStakingAuction(_ views: UInt64) {
            self.numViewsInStakingAuction = views
        }

        /// The number of views in each dkg phase
        access(all) var numViewsInDKGPhase: UInt64

        access(all) fun setNumViewsInDKGPhase(_ views: UInt64) {
            self.numViewsInDKGPhase = views
        }

        /// The number of collector clusters in each epoch
        access(all) var numCollectorClusters: UInt16

        access(all) fun setNumCollectorClusters(_ numClusters: UInt16) {
            self.numCollectorClusters = numClusters
        }

        /// Tracks the rate at which the rewards payout increases every epoch
        /// This value is multiplied by the FLOW total supply to get the next payout
        access(all) var FLOWsupplyIncreasePercentage: UFix64

        access(all) fun setFLOWsupplyIncreasePercentage(_ percentage: UFix64) {
            self.FLOWsupplyIncreasePercentage = percentage
        }

        init(numViewsInEpoch: UInt64, numViewsInStakingAuction: UInt64, numViewsInDKGPhase: UInt64, numCollectorClusters: UInt16, FLOWsupplyIncreasePercentage: UFix64) {
            self.numViewsInEpoch = numViewsInEpoch
            self.numViewsInStakingAuction = numViewsInStakingAuction
            self.numViewsInDKGPhase = numViewsInDKGPhase
            self.numCollectorClusters = numCollectorClusters
            self.FLOWsupplyIncreasePercentage = FLOWsupplyIncreasePercentage
        }
    }

    /// Configuration for epoch timing.
    /// Each epoch is assigned a target end time when it is setup (within the EpochSetup event).
    /// The configuration defines a reference epoch counter and timestamp, which defines
    /// all future target end times. If `targetEpochCounter` is an upcoming epoch, then
    /// its target end time is given by:
    ///
    ///   targetEndTime = refTimestamp + duration * (targetEpochCounter-refCounter)
    ///
    access(all) struct EpochTimingConfig {
        /// The duration of each epoch, in seconds
        access(all) let duration: UInt64
        /// The counter of the reference epoch
        access(all) let refCounter: UInt64
        /// The end time of the reference epoch, specified in second-precision Unix time
        access(all) let refTimestamp: UInt64

        /// Compute target switchover time based on offset from reference counter/switchover.
        access(all) fun getTargetEndTimeForEpoch(_ targetEpochCounter: UInt64): UInt64 {
            return self.refTimestamp + self.duration * (targetEpochCounter-self.refCounter)
        }

        init(duration: UInt64, refCounter: UInt64, refTimestamp: UInt64) {
             self.duration = duration
             self.refCounter = refCounter
             self.refTimestamp = refTimestamp
        }
    }

    /// Holds the `FlowEpoch.Config` struct with the configurable metadata
    access(contract) let configurableMetadata: Config

    /// Metadata that is managed by the smart contract
    /// and cannot be changed by the Admin

    /// Contains a historical record of the metadata from all previous epochs
    /// indexed by epoch number

    /// Returns the metadata from the specified epoch
    /// or nil if it isn't found
    /// Epoch Metadata is stored in account storage so the growing dictionary
    /// does not have to be loaded every time the contract is loaded
    access(all) fun getEpochMetadata(_ epochCounter: UInt64): EpochMetadata? {
        if let metadataDictionary = self.account.storage.borrow<&{UInt64: EpochMetadata}>(from: self.metadataStoragePath) {
            if let metadataRef = metadataDictionary[epochCounter] {
                return metadataRef.copy()
            }
        }
        return nil
    }

    /// Saves a modified EpochMetadata struct to the metadata in account storage
    access(contract) fun saveEpochMetadata(_ newMetadata: EpochMetadata) {
        pre {
            self.currentEpochCounter == 0 ||
            (newMetadata.counter >= self.currentEpochCounter - 1 &&
            newMetadata.counter <= self.proposedEpochCounter()):
                "Cannot modify epoch metadata from epochs after the proposed epoch or before the previous epoch"
        }
        if let metadataDictionary = self.account.storage.borrow<auth(Mutate) &{UInt64: EpochMetadata}>(from: self.metadataStoragePath) {
            if let metadata = metadataDictionary[newMetadata.counter] {
                assert (
                    metadata.counter == newMetadata.counter,
                    message: "Cannot save metadata with mismatching epoch counters"
                )
            }
            metadataDictionary[newMetadata.counter] = newMetadata
        }
    }

    /// Generates 128 bits of randomness using system random (derived from Random Beacon).
    access(contract) fun generateRandomSource(): String {
        post {
            result.length == 32:
                "FlowEpoch.generateRandomSource: Critical invariant violated! "
                    .concat("Expected hex random source with length 32 (128 bits) but got length ")
                    .concat(result.length.toString())
                    .concat(" instead.")
        }
        var randomSource = String.encodeHex(revertibleRandom<UInt128>().toBigEndianBytes())
        return randomSource
    }

    /// The counter, or ID, of the current epoch
    access(all) var currentEpochCounter: UInt64

    /// The current phase that the epoch is in
    access(all) var currentEpochPhase: EpochPhase

    /// Path where the `FlowEpoch.Admin` resource is stored
    access(all) let adminStoragePath: StoragePath

    /// Path where the `FlowEpoch.Heartbeat` resource is stored
    access(all) let heartbeatStoragePath: StoragePath

    /// Path where the `{UInt64: EpochMetadata}` dictionary is stored
    access(all) let metadataStoragePath: StoragePath

    /// Resource that can update some of the contract fields
    access(all) resource Admin {
        access(all) fun updateEpochViews(_ newEpochViews: UInt64) {
            pre {
                FlowEpoch.currentEpochPhase == EpochPhase.STAKINGAUCTION: "Can only update fields during the staking auction"
                FlowEpoch.isValidPhaseConfiguration(FlowEpoch.configurableMetadata.numViewsInStakingAuction,
                    FlowEpoch.configurableMetadata.numViewsInDKGPhase,
                    newEpochViews): "New Epoch Views must be greater than the sum of staking and DKG Phase views"
            }

            FlowEpoch.configurableMetadata.setNumViewsInEpoch(newEpochViews)
        }

        access(all) fun updateAuctionViews(_ newAuctionViews: UInt64) {
            pre {
                FlowEpoch.currentEpochPhase == EpochPhase.STAKINGAUCTION: "Can only update fields during the staking auction"
                FlowEpoch.isValidPhaseConfiguration(newAuctionViews,
                    FlowEpoch.configurableMetadata.numViewsInDKGPhase,
                    FlowEpoch.configurableMetadata.numViewsInEpoch): "Epoch Views must be greater than the sum of new staking and DKG Phase views"
            }

            FlowEpoch.configurableMetadata.setNumViewsInStakingAuction(newAuctionViews)
        }

        access(all) fun updateDKGPhaseViews(_ newPhaseViews: UInt64) {
            pre {
                FlowEpoch.currentEpochPhase == EpochPhase.STAKINGAUCTION: "Can only update fields during the staking auction"
                FlowEpoch.isValidPhaseConfiguration(FlowEpoch.configurableMetadata.numViewsInStakingAuction,
                    newPhaseViews,
                    FlowEpoch.configurableMetadata.numViewsInEpoch): "Epoch Views must be greater than the sum of staking and new DKG Phase views"
            }

            FlowEpoch.configurableMetadata.setNumViewsInDKGPhase(newPhaseViews)
        }

        access(all) fun updateEpochTimingConfig(_ newConfig: EpochTimingConfig) {
            pre {
                FlowEpoch.currentEpochCounter >= newConfig.refCounter: "Reference epoch must be before next epoch"
            }
            FlowEpoch.account.storage.load<EpochTimingConfig>(from: /storage/flowEpochTimingConfig)
            FlowEpoch.account.storage.save(newConfig, to: /storage/flowEpochTimingConfig)
        }

        access(all) fun updateNumCollectorClusters(_ newNumClusters: UInt16) {
            pre {
                FlowEpoch.currentEpochPhase == EpochPhase.STAKINGAUCTION: "Can only update fields during the staking auction"
            }

            FlowEpoch.configurableMetadata.setNumCollectorClusters(newNumClusters)
        }

        access(all) fun updateFLOWSupplyIncreasePercentage(_ newPercentage: UFix64) {
            pre {
                FlowEpoch.currentEpochPhase == EpochPhase.STAKINGAUCTION: "Can only update fields during the staking auction"
                newPercentage <= 1.0: "New value must be between zero and one"
            }

            FlowEpoch.configurableMetadata.setFLOWsupplyIncreasePercentage(newPercentage)
        }

        // Enable or disable automatic rewards calculations and payments
        access(all) fun updateAutomaticRewardsEnabled(_ enabled: Bool) {
            FlowEpoch.account.storage.load<Bool>(from: /storage/flowAutomaticRewardsEnabled)
            FlowEpoch.account.storage.save(enabled, to: /storage/flowAutomaticRewardsEnabled)
        }
        /// Emits the EpochRecover service event. Inputs for the recovery epoch will be validated before the recover event is emitted.
        /// This func should only be used during the epoch recovery governance intervention.
        access(self) fun emitEpochRecoverEvent(epochCounter: UInt64,
            startView: UInt64,
            stakingEndView: UInt64,
            endView: UInt64,
            nodeIDs: [String],
            clusterAssignments: [[String]],
            randomSource: String,
            targetDuration: UInt64,
            targetEndTime: UInt64,
            clusterQCVoteData: [FlowClusterQC.ClusterQCVoteData],
            dkgPubKeys: [String],
            dkgGroupKey: String,
            dkgIdMapping: {String: Int},
            ) {
            self.recoverEpochPreChecks(
                startView: startView, 
                stakingEndView: stakingEndView, 
                endView: endView, 
                nodeIDs: nodeIDs,
                numOfClusterAssignments: clusterAssignments.length,
                numOfClusterQCVoteData: clusterQCVoteData.length,
            )
            /// Construct the identity table for the recovery epoch
            let nodes: [FlowIDTableStaking.NodeInfo] = []
            for nodeID in nodeIDs {
                nodes.append(FlowIDTableStaking.NodeInfo(nodeID: nodeID))
            }
            
            let numViewsInDKGPhase = FlowEpoch.configurableMetadata.numViewsInDKGPhase
            let dkgPhase1FinalView = stakingEndView + numViewsInDKGPhase
            let dkgPhase2FinalView = dkgPhase1FinalView + numViewsInDKGPhase
            let dkgPhase3FinalView = dkgPhase2FinalView + numViewsInDKGPhase

            /// emit EpochRecover event
            emit FlowEpoch.EpochRecover(
                counter: epochCounter,
                nodeInfo: nodes,
                firstView: startView,
                finalView: endView,
                clusterAssignments: clusterAssignments,
                randomSource: randomSource,
                DKGPhase1FinalView: dkgPhase1FinalView,
                DKGPhase2FinalView: dkgPhase2FinalView,
                DKGPhase3FinalView: dkgPhase3FinalView,
                targetDuration: targetDuration,
                targetEndTime: targetEndTime,
                clusterQCVoteData: clusterQCVoteData,
                dkgPubKeys: dkgPubKeys,
                dkgGroupKey: dkgGroupKey,
                dkgIdMapping: dkgIdMapping,
            )
        }

        /// Performs sanity checks for the provided epoch configuration. It will ensure the following;
        /// - There is a valid phase configuration.
        /// - All nodes in the node ids list have a weight > 0.
        access(self) fun recoverEpochPreChecks(startView: UInt64,
            stakingEndView: UInt64,
            endView: UInt64,
            nodeIDs: [String],
            numOfClusterAssignments: Int,
            numOfClusterQCVoteData: Int) 
        {
            pre {
                FlowEpoch.isValidPhaseConfiguration(stakingEndView-startView+1, FlowEpoch.configurableMetadata.numViewsInDKGPhase, endView-startView+1):
                    "Invalid startView, stakingEndView, and endView configuration"
            }

            /// sanity check all nodes should have a weight > 0
            for nodeID in nodeIDs {
                assert(
                    FlowIDTableStaking.NodeInfo(nodeID: nodeID).initialWeight > 0, 
                    message: "FlowEpoch.Admin.recoverEpochPreChecks: All nodes in node ids list for recovery epoch must have a weight > 0. The node "
                    .concat(nodeID).concat(" has a weight of 0.")
                )
            }

            // sanity check we must receive qc vote data for each cluster
            assert(
                numOfClusterAssignments == numOfClusterQCVoteData, 
                message: "FlowEpoch.Admin.recoverEpochPreChecks: The number of cluster assignments "
                .concat(numOfClusterAssignments.toString()).concat(" does not match the number of cluster qc vote data ")
                .concat(numOfClusterQCVoteData.toString())
            )
        }
        
        /// Stops epoch components. When we are in the StakingAuction phase the staking auction is stopped 
        /// otherwise cluster qc voting and the dkg is stopped.
        access(self) fun stopEpochComponents() {
            if FlowEpoch.currentEpochPhase == EpochPhase.STAKINGAUCTION {
                /// Since we are resetting the epoch, we do not need to
                /// start epoch setup also. We only need to end the staking auction
                FlowEpoch.borrowStakingAdmin().endStakingAuction()
            } else {
                /// force reset the QC and DKG
                FlowEpoch.borrowClusterQCAdmin().forceStopVoting()
                FlowEpoch.borrowDKGAdmin().forceEndDKG()
            }
        }

        /// Ends the currently active epoch and starts a new "recovery epoch" with the provided configuration.
        /// This function is used to recover from Epoch Fallback Mode (EFM).
        /// The "recovery epoch" config will be emitted in the EpochRecover service event.
        /// The "recovery epoch" must have a counter exactly one greater than the current epoch counter.
        /// 
        /// This function differs from recoverCurrentEpoch because it increments the epoch counter and will calculate rewards. 
        access(all) fun recoverNewEpoch(
            recoveryEpochCounter: UInt64,
            startView: UInt64,
            stakingEndView: UInt64,
            endView: UInt64,
            targetDuration: UInt64,
            targetEndTime: UInt64,
            clusterAssignments: [[String]],
            clusterQCVoteData: [FlowClusterQC.ClusterQCVoteData],
            dkgPubKeys: [String],
            dkgGroupKey: String,
            dkgIdMapping: {String: Int},
            nodeIDs: [String]) 
        {
            pre {
                recoveryEpochCounter == FlowEpoch.proposedEpochCounter():
                    "FlowEpoch.Admin.recoverNewEpoch: Recovery epoch counter must equal current epoch counter + 1. "
                        .concat("Got recovery epoch counter (")
                        .concat(recoveryEpochCounter.toString())
                        .concat(") with current epoch counter (")
                        .concat(FlowEpoch.currentEpochCounter.toString())
                        .concat(").")
            }

            self.stopEpochComponents()
            let randomSource = FlowEpoch.generateRandomSource()

            /// Create new EpochMetadata for the recovery epoch with the new values
            let newEpochMetadata = EpochMetadata(
                /// Increment the epoch counter when recovering with a new epoch
                counter: recoveryEpochCounter,
                seed: randomSource,
                startView: startView,
                endView: endView,
                stakingEndView: stakingEndView,
                totalRewards: 0.0,     // will be overwritten in `calculateAndSetRewards` below
                collectorClusters: [],
                clusterQCs: [],
                dkgKeys: [dkgGroupKey].concat(dkgPubKeys)
            )

            /// Save the new epoch meta data, it will be referenced as the epoch progresses
            FlowEpoch.saveEpochMetadata(newEpochMetadata)

            /// Calculate rewards for the current epoch and set the payout for the next epoch
            FlowEpoch.calculateAndSetRewards()

            /// Emit the EpochRecover service event.
            /// This will be processed by the Protocol State, which will then exit EFM
            /// and enter the recovery epoch at the specified start view.
            self.emitEpochRecoverEvent(epochCounter: recoveryEpochCounter,
                startView: startView,
                stakingEndView: stakingEndView,
                endView: endView,
                nodeIDs: nodeIDs,
                clusterAssignments: clusterAssignments,
                randomSource: randomSource,
                targetDuration: targetDuration,
                targetEndTime: targetEndTime,
                clusterQCVoteData: clusterQCVoteData,
                dkgPubKeys: dkgPubKeys,
                dkgGroupKey: dkgGroupKey,
                dkgIdMapping: dkgIdMapping,
            )

            /// Start a new Epoch, which increments the current epoch counter
            FlowEpoch.startNewEpoch()
        }

        /// Replaces the currently active epoch with a new "recovery epoch" with the provided configuration.
        /// This function is used to recover from Epoch Fallback Mode (EFM).
        /// The "recovery epoch" config will be emitted in the EpochRecover service event.
        /// The "recovery epoch must have a counter exactly equal to the current epoch counter.
        /// 
        /// This function differs from recoverNewEpoch because it replaces the currently active epoch instead of starting a new epoch.
        /// This function does not calculate or distribute rewards
        /// Calling recoverCurrentEpoch multiple times does not cause multiple reward payouts.
        /// Rewards for the recovery epoch will be calculated and paid out during the course of the epoch. 
        /// CAUTION: This causes data loss by replacing the existing current epoch metadata with the inputs to this function.
        /// This function exists to recover from potential race conditions that caused a prior recoverCurrentEpoch transaction to fail;
        /// this allows operators to retry the recovery procedure, overwriting the prior failed attempt.
        access(all) fun recoverCurrentEpoch(
            recoveryEpochCounter: UInt64,
            startView: UInt64,
            stakingEndView: UInt64,
            endView: UInt64,
            targetDuration: UInt64,
            targetEndTime: UInt64,
            clusterAssignments: [[String]],
            clusterQCVoteData: [FlowClusterQC.ClusterQCVoteData],
            dkgPubKeys: [String],
            dkgGroupKey: String,
            dkgIdMapping: {String: Int},
            nodeIDs: [String]) 
        { 
            pre {
                recoveryEpochCounter == FlowEpoch.currentEpochCounter:
                    "FlowEpoch.Admin.recoverCurrentEpoch: Recovery epoch counter must equal current epoch counter. "
                        .concat("Got recovery epoch counter (")
                        .concat(recoveryEpochCounter.toString())
                        .concat(") with current epoch counter (")
                        .concat(FlowEpoch.currentEpochCounter.toString())
                        .concat(").")
            }

            self.stopEpochComponents()
            FlowEpoch.currentEpochPhase = EpochPhase.STAKINGAUCTION
            
            let currentEpochMetadata = FlowEpoch.getEpochMetadata(recoveryEpochCounter)
            /// Create new EpochMetadata for the recovery epoch with the new values.
            /// This epoch metadata will overwrite the epoch metadata of the current epoch.
            let recoveryEpochMetadata: FlowEpoch.EpochMetadata = EpochMetadata(
                counter: recoveryEpochCounter,
                seed: currentEpochMetadata!.seed,
                startView: startView,
                endView: endView,
                stakingEndView: stakingEndView,
                totalRewards: currentEpochMetadata!.totalRewards,
                collectorClusters: [],
                clusterQCs: [],
                dkgKeys: [dkgGroupKey].concat(dkgPubKeys)
            )

            /// Save EpochMetadata for the recovery epoch, it will be referenced as the epoch progresses.
            /// CAUTION: This overwrites the EpochMetadata already stored for the current epoch.
            FlowEpoch.saveEpochMetadata(recoveryEpochMetadata)

            /// Emit the EpochRecover service event.
            /// This will be processed by the Protocol State, which will then exit EFM
            /// and enter the recovery epoch at the specified start view.
            self.emitEpochRecoverEvent( 
                epochCounter: recoveryEpochCounter,
                startView: startView,
                stakingEndView: stakingEndView,
                endView: endView,
                nodeIDs: nodeIDs,
                clusterAssignments: clusterAssignments,
                randomSource: recoveryEpochMetadata.seed,
                targetDuration: targetDuration,
                targetEndTime: targetEndTime,
                clusterQCVoteData: clusterQCVoteData,
                dkgPubKeys: dkgPubKeys,
                dkgGroupKey: dkgGroupKey,
                dkgIdMapping: dkgIdMapping,
            )
        }

        /// Ends the currently active epoch and starts a new one with the provided configuration.
        /// The new epoch, after resetEpoch completes, has `counter = currentEpochCounter + 1`.
        /// This function is used during sporks - since the consensus view is reset, and the protocol is
        /// bootstrapped with a new initial state snapshot, this initializes FlowEpoch with the first epoch
        /// of the new spork, as defined in that snapshot.
        access(all) fun resetEpoch(
            currentEpochCounter: UInt64,
            randomSource: String,
            startView: UInt64,
            stakingEndView: UInt64,
            endView: UInt64,
            collectorClusters: [FlowClusterQC.Cluster],
            clusterQCs: [FlowClusterQC.ClusterQC],
            dkgPubKeys: [String])
        {
            pre {
                currentEpochCounter == FlowEpoch.currentEpochCounter:
                    "Cannot submit a current Epoch counter that does not match the current counter stored in the smart contract"
                FlowEpoch.isValidPhaseConfiguration(stakingEndView-startView+1, FlowEpoch.configurableMetadata.numViewsInDKGPhase, endView-startView+1):
                    "Invalid startView, stakingEndView, and endView configuration"
            }

            self.stopEpochComponents()

            // Create new Epoch metadata for the next epoch
            // with the new values
            let newEpochMetadata = EpochMetadata(
                    counter: currentEpochCounter + 1,
                    seed: randomSource,
                    startView: startView,
                    endView: endView,
                    stakingEndView: stakingEndView,
                    totalRewards: 0.0, // will be overwritten in calculateAndSetRewards below
                    collectorClusters: collectorClusters,
                    clusterQCs: clusterQCs,
                    dkgKeys: dkgPubKeys)

            FlowEpoch.saveEpochMetadata(newEpochMetadata)

            // Calculate rewards for the current epoch
            // and set the payout for the next epoch
            FlowEpoch.calculateAndSetRewards()

            // Start a new Epoch, which increments the current epoch counter
            FlowEpoch.startNewEpoch()
        }
    }

    /// Resource that is controlled by the protocol and is used
    /// to change the current phase of the epoch or reset the epoch if needed
    access(all) resource Heartbeat {
        /// Function that is called every block to advance the epoch
        /// and change phase if the required conditions have been met
        access(all) fun advanceBlock() {
            switch FlowEpoch.currentEpochPhase {
                case EpochPhase.STAKINGAUCTION:
                    let currentBlock = getCurrentBlock()
                    let currentEpochMetadata = FlowEpoch.getEpochMetadata(FlowEpoch.currentEpochCounter)!
                    // Pay rewards only if automatic rewards are enabled
                    // This will only actually happen once immediately after the epoch begins
                    // because `payRewardsForPreviousEpoch()` will only pay rewards once
                    if FlowEpoch.automaticRewardsEnabled() {
                        self.payRewardsForPreviousEpoch()
                    }
                    if currentBlock.view >= currentEpochMetadata.stakingEndView {
                        self.endStakingAuction()
                    }
                case EpochPhase.EPOCHSETUP:
                    if FlowClusterQC.votingCompleted() && (FlowDKG.dkgCompleted() != nil) {
                        self.calculateAndSetRewards()
                        self.startEpochCommit()
                    }
                case EpochPhase.EPOCHCOMMIT:
                    let currentBlock = getCurrentBlock()
                    let currentEpochMetadata = FlowEpoch.getEpochMetadata(FlowEpoch.currentEpochCounter)!
                    if currentBlock.view >= currentEpochMetadata.endView {
                        self.endEpoch()
                    }
                default:
                    return
            }
        }

        /// Calls `FlowEpoch` functions to end the staking auction phase
        /// and start the Epoch Setup phase
        access(all) fun endStakingAuction() {
            pre {
                FlowEpoch.currentEpochPhase == EpochPhase.STAKINGAUCTION: "Can only end staking auction during the staking auction"
            }

            let proposedNodeIDs = FlowEpoch.endStakingAuction()

            /// random source must be a hex string of 32 characters (i.e 16 bytes or 128 bits)
            let randomSource = FlowEpoch.generateRandomSource()

            FlowEpoch.startEpochSetup(proposedNodeIDs: proposedNodeIDs, randomSource: randomSource)
        }

        /// Calls `FlowEpoch` functions to end the Epoch Setup phase
        /// and start the Epoch Setup Phase
        access(all) fun startEpochCommit() {
            pre {
                FlowEpoch.currentEpochPhase == EpochPhase.EPOCHSETUP: "Can only end Epoch Setup during Epoch Setup"
            }

            FlowEpoch.startEpochCommit()
        }

        /// Calls `FlowEpoch` functions to end the Epoch Commit phase
        /// and start the Staking Auction phase of a new epoch
        access(all) fun endEpoch() {
            pre {
                FlowEpoch.currentEpochPhase == EpochPhase.EPOCHCOMMIT: "Can only end epoch during Epoch Commit"
            }

            FlowEpoch.startNewEpoch()
        }

        /// Needs to be called before the epoch is over
        /// Calculates rewards for the current epoch and stores them in epoch metadata
        access(all) fun calculateAndSetRewards() {
            FlowEpoch.calculateAndSetRewards()
        }

        access(all) fun payRewardsForPreviousEpoch() {
            FlowEpoch.payRewardsForPreviousEpoch()
        }
    }

    /// Calculates a new token payout for the current epoch
    /// and sets the new payout for the next epoch
    access(account) fun calculateAndSetRewards() {

        let stakingAdmin = self.borrowStakingAdmin()

        // Calculate rewards for the current epoch that is about to end
        // and save that reward breakdown in the epoch metadata for the current epoch
        let rewardsSummary = stakingAdmin.calculateRewards()
        let currentMetadata = self.getEpochMetadata(self.currentEpochCounter)!
        currentMetadata.setRewardAmounts(rewardsSummary.breakdown)
        currentMetadata.setTotalRewards(rewardsSummary.totalRewards)
        self.saveEpochMetadata(currentMetadata)

        if FlowEpoch.automaticRewardsEnabled() {
            // Calculate the total supply of FLOW after the current epoch's payout
            // the calculation includes the tokens that haven't been minted for the current epoch yet
            let currentPayout = FlowIDTableStaking.getEpochTokenPayout()
            let feeAmount = FlowFees.getFeeBalance()
            var flowTotalSupplyAfterPayout = 0.0
            if feeAmount >= currentPayout {
                flowTotalSupplyAfterPayout = FlowToken.totalSupply
            } else {
                flowTotalSupplyAfterPayout = FlowToken.totalSupply + (currentPayout - feeAmount)
            }

            // Load the amount of bonus tokens from storage
            let bonusTokens = FlowEpoch.getBonusTokens()

            // Subtract bonus tokens from the total supply to get the real supply
            if bonusTokens < flowTotalSupplyAfterPayout {
                flowTotalSupplyAfterPayout = flowTotalSupplyAfterPayout - bonusTokens
            }

            // Calculate the payout for the next epoch
            let proposedPayout = flowTotalSupplyAfterPayout * FlowEpoch.configurableMetadata.FLOWsupplyIncreasePercentage

            // Set the new payout in the staking contract and proposed Epoch Metadata
            self.borrowStakingAdmin().setEpochTokenPayout(proposedPayout)
            let proposedMetadata = self.getEpochMetadata(self.proposedEpochCounter())
                ?? panic("Cannot set rewards for the next epoch becuase it hasn't been proposed yet")
            proposedMetadata.setTotalRewards(proposedPayout)
            self.saveEpochMetadata(proposedMetadata)
        }
    }

    /// Pays rewards to the nodes and delegators of the previous epoch
    access(account) fun payRewardsForPreviousEpoch() {
        if let previousEpochMetadata = self.getEpochMetadata(self.currentEpochCounter - 1) {
            if !previousEpochMetadata.rewardsPaid {
                let summary = FlowIDTableStaking.EpochRewardsSummary(totalRewards: previousEpochMetadata.totalRewards, breakdown: previousEpochMetadata.rewardAmounts)
                self.borrowStakingAdmin().payRewards(forEpochCounter: previousEpochMetadata.counter, rewardsSummary: summary)
                previousEpochMetadata.setRewardsPaid(true)
                self.saveEpochMetadata(previousEpochMetadata)
            }
        }
    }

    /// Moves staking tokens between buckets,
    /// and starts the new epoch staking auction
    access(account) fun startNewEpoch() {

        // End QC and DKG if they are still enabled
        if FlowClusterQC.inProgress {
            self.borrowClusterQCAdmin().stopVoting()
        }
        if FlowDKG.dkgEnabled {
            self.borrowDKGAdmin().endDKG()
        }

        self.borrowStakingAdmin().moveTokens(newEpochCounter: self.proposedEpochCounter())

        self.currentEpochPhase = EpochPhase.STAKINGAUCTION

        // Update the epoch counters
        self.currentEpochCounter = self.proposedEpochCounter()

        let previousEpochMetadata = self.getEpochMetadata(self.currentEpochCounter - 1)!
        let newEpochMetadata = self.getEpochMetadata(self.currentEpochCounter)!

        emit EpochStart (
            counter: self.currentEpochCounter,
            firstView: newEpochMetadata.startView,
            stakingAuctionEndView: newEpochMetadata.stakingEndView,
            finalView: newEpochMetadata.endView,
            totalStaked: FlowIDTableStaking.getTotalStaked(),
            totalFlowSupply: FlowToken.totalSupply + previousEpochMetadata.totalRewards,
            totalRewards: FlowIDTableStaking.getEpochTokenPayout(),
        )
    }

    /// Ends the staking Auction with all the proposed nodes approved
    access(account) fun endStakingAuction(): [String] {
        return self.borrowStakingAdmin().endStakingAuction()
    }

    /// Starts the EpochSetup phase and emits the epoch setup event
    /// This has to be called directly after `endStakingAuction`
    access(account) fun startEpochSetup(proposedNodeIDs: [String], randomSource: String) {

        // Holds the node Information of all the approved nodes
        var nodeInfoArray: [FlowIDTableStaking.NodeInfo] = []

        // Holds node IDs of only collector nodes for QC
        var collectorNodeIDs: [String] = []

        // Holds node IDs of only consensus nodes for DKG
        var consensusNodeIDs: [String] = []

        // Get NodeInfo for all the nodes
        // Get all the collector and consensus nodes
        // to initialize the QC and DKG
        for id in proposedNodeIDs {
            let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: id)

            nodeInfoArray.append(nodeInfo)

            if nodeInfo.role == NodeRole.Collector.rawValue {
                collectorNodeIDs.append(nodeInfo.id)
            }

            if nodeInfo.role == NodeRole.Consensus.rawValue {
                consensusNodeIDs.append(nodeInfo.id)
            }
        }

        // Organize the collector nodes into clusters
        let collectorClusters = self.createCollectorClusters(nodeIDs: collectorNodeIDs)

        // Start QC Voting with the supplied clusters
        self.borrowClusterQCAdmin().startVoting(clusters: collectorClusters)

        // Start DKG with the consensus nodes
        self.borrowDKGAdmin().startDKG(nodeIDs: consensusNodeIDs)

        let currentEpochMetadata = self.getEpochMetadata(self.currentEpochCounter)!

        // Initialize the metadata for the next epoch
        // QC and DKG metadata will be filled in later
        let proposedEpochMetadata = EpochMetadata(counter: self.proposedEpochCounter(),
                                                seed: randomSource,
                                                startView: currentEpochMetadata.endView + UInt64(1),
                                                endView: currentEpochMetadata.endView + self.configurableMetadata.numViewsInEpoch,
                                                stakingEndView: currentEpochMetadata.endView + self.configurableMetadata.numViewsInStakingAuction,
                                                totalRewards: 0.0,
                                                collectorClusters: collectorClusters,
                                                clusterQCs: [],
                                                dkgKeys: [])

        // Compute the target end time for the next epoch
        let timingConfig = self.getEpochTimingConfig()
        let proposedTargetDuration = timingConfig.duration
        let proposedTargetEndTime = timingConfig.getTargetEndTimeForEpoch(self.proposedEpochCounter())

        self.saveEpochMetadata(proposedEpochMetadata)

        self.currentEpochPhase = EpochPhase.EPOCHSETUP

        let dkgPhase1FinalView = proposedEpochMetadata.stakingEndView + self.configurableMetadata.numViewsInDKGPhase
        let dkgPhase2FinalView = dkgPhase1FinalView + self.configurableMetadata.numViewsInDKGPhase
        let dkgPhase3FinalView = dkgPhase2FinalView + self.configurableMetadata.numViewsInDKGPhase
        emit EpochSetup(counter: proposedEpochMetadata.counter,
                        nodeInfo: nodeInfoArray,
                        firstView: proposedEpochMetadata.startView,
                        finalView: proposedEpochMetadata.endView,
                        collectorClusters: collectorClusters,
                        randomSource: randomSource,
                        DKGPhase1FinalView: dkgPhase1FinalView,
                        DKGPhase2FinalView:  dkgPhase2FinalView,
                        DKGPhase3FinalView:  dkgPhase3FinalView,
                        targetDuration: proposedTargetDuration,
                        targetEndTime: proposedTargetEndTime)
    }

    /// Ends the EpochSetup phase when the QC and DKG are completed
    /// and emits the EpochCommit event with the results
    access(account) fun startEpochCommit() {
        if !FlowClusterQC.votingCompleted() || FlowDKG.dkgCompleted() == nil {
            return
        }

        let clusters = FlowClusterQC.getClusters()

        // Holds the quorum certificates for each cluster
        var clusterQCs: [FlowClusterQC.ClusterQC] = []

        // iterate through all the clusters and create their certificate arrays
        for cluster in clusters {
            var certificate = cluster.generateQuorumCertificate()
                ?? panic("Could not generate the quorum certificate for this cluster")

            clusterQCs.append(certificate)
        }

        // Set cluster QCs in the proposed epoch metadata and stop QC voting
        let proposedEpochMetadata = self.getEpochMetadata(self.proposedEpochCounter())!
        proposedEpochMetadata.setClusterQCs(qcs: clusterQCs)

        // Set DKG result in the proposed epoch metadata and stop DKG
        let dkgResult = FlowDKG.dkgCompleted()!
        // Construct a partial representation of the DKG result for storage in the epoch metadata.
        // See setDKGKeys documentation for context on why the node ID mapping is omitted here.
        let dkgPubKeys = [dkgResult.groupPubKey!].concat(dkgResult.pubKeys!)
        proposedEpochMetadata.setDKGKeys(keys: dkgPubKeys)
        self.saveEpochMetadata(proposedEpochMetadata)

        self.currentEpochPhase = EpochPhase.EPOCHCOMMIT

        emit EpochCommit(counter: self.proposedEpochCounter(),
                            clusterQCs: clusterQCs,
                            dkgPubKeys: dkgResult.pubKeys!,
                            dkgGroupKey: dkgResult.groupPubKey!,
                            dkgIdMapping: dkgResult.idMapping!)
    }

    /// Borrow a reference to the FlowIDTableStaking Admin resource
    access(contract) view fun borrowStakingAdmin(): &FlowIDTableStaking.Admin {
        let adminCapability = self.account.storage.copy<Capability>(from: /storage/flowStakingAdminEpochOperations)
            ?? panic("Could not get capability from account storage")

        // borrow a reference to the staking admin object
        let adminRef = adminCapability.borrow<&FlowIDTableStaking.Admin>()
            ?? panic("Could not borrow reference to staking admin")

        return adminRef
    }

    /// Borrow a reference to the ClusterQCs Admin resource
    access(contract) fun borrowClusterQCAdmin(): &FlowClusterQC.Admin {
        let adminCapability = self.account.storage.copy<Capability>(from: /storage/flowQCAdminEpochOperations)
            ?? panic("Could not get capability from account storage")

        // borrow a reference to the QC admin object
        let adminRef = adminCapability.borrow<&FlowClusterQC.Admin>()
            ?? panic("Could not borrow reference to QC admin")

        return adminRef
    }

    /// Borrow a reference to the DKG Admin resource
    access(contract) fun borrowDKGAdmin(): &FlowDKG.Admin {
        let adminCapability = self.account.storage.copy<Capability>(from: /storage/flowDKGAdminEpochOperations)
            ?? panic("Could not get capability from account storage")

        // borrow a reference to the dkg admin object
        let adminRef = adminCapability.borrow<&FlowDKG.Admin>()
            ?? panic("Could not borrow reference to dkg admin")

        return adminRef
    }

    /// Makes sure the set of phase lengths (in views) are valid.
    /// Sub-phases cannot be greater than the full epoch length.
    access(all) view fun isValidPhaseConfiguration(_ auctionLen: UInt64, _ dkgPhaseLen: UInt64, _ epochLen: UInt64): Bool {
        return (auctionLen + (3*dkgPhaseLen)) < epochLen
    }

    /// Randomizes the list of collector node ID and uses a round robin algorithm
    /// to assign all collector nodes to equal sized clusters
    access(all) fun createCollectorClusters(nodeIDs: [String]): [FlowClusterQC.Cluster] {
        pre {
            UInt16(nodeIDs.length) >= self.configurableMetadata.numCollectorClusters: "Cannot have less collector nodes than clusters"
        }
        var shuffledIDs = self.randomize(nodeIDs)

        // Holds cluster assignments for collector nodes
        let clusters: [FlowClusterQC.Cluster] = []
        var clusterIndex: UInt16 = 0
        let nodeWeightsDictionary: [{String: UInt64}] = []
        while clusterIndex < self.configurableMetadata.numCollectorClusters {
            nodeWeightsDictionary.append({})
            clusterIndex = clusterIndex + 1
        }
        clusterIndex = 0

        for id in shuffledIDs {

            let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: id)

            nodeWeightsDictionary[clusterIndex][id] = nodeInfo.initialWeight

            // Advance to the next cluster, or back to the first if we have gotten to the last one
            clusterIndex = clusterIndex + 1
            if clusterIndex == self.configurableMetadata.numCollectorClusters {
                clusterIndex = 0
            }
        }

        // Create the clusters Array that is sent to the QC contract
        // and emitted in the EpochSetup event
        clusterIndex = 0
        while clusterIndex < self.configurableMetadata.numCollectorClusters {
            clusters.append(FlowClusterQC.Cluster(index: clusterIndex, nodeWeights: nodeWeightsDictionary[clusterIndex]!))
            clusterIndex = clusterIndex + 1
        }

        return clusters
    }

    /// A function to generate a random permutation of arr[]
    /// using the fisher yates shuffling algorithm
    access(all) fun randomize(_ array: [String]): [String] {

        var i = array.length - 1

        // Start from the last element and swap one by one. We don't
        // need to run for the first element that's why i > 0
        while i > 0
        {
            // Pick a random index from 0 to i
            /// TODO: this naive implementation is unnecessarily costly at runtime -- update with revertibleRandom<UInt64>(i+1) when available
            var randomNum = revertibleRandom<UInt64>()
            var randomIndex = randomNum % UInt64(i + 1)

            // Swap arr[i] with the element at random index
            var temp = array[i]
            array[i] = array[randomIndex]
            array[randomIndex] = temp

            i = i - 1
        }

        return array
    }

    /// Collector nodes call this function to get their QC Voter resource
    /// in order to participate the the QC generation for their cluster
    access(all) fun getClusterQCVoter(nodeStaker: &FlowIDTableStaking.NodeStaker): @FlowClusterQC.Voter {
        let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeStaker.id)

        assert (
            nodeInfo.role == NodeRole.Collector.rawValue,
            message: "Node operator must be a collector node to get a QC Voter object"
        )

        let clusterQCAdmin = self.borrowClusterQCAdmin()
        return <-clusterQCAdmin.createVoter(nodeID: nodeStaker.id, stakingKey: nodeInfo.stakingKey)
    }

    /// Consensus nodes call this function to get their DKG Participant resource
    /// in order to participate in the DKG for the next epoch
    access(all) fun getDKGParticipant(nodeStaker: &FlowIDTableStaking.NodeStaker): @FlowDKG.Participant {
        let nodeInfo = FlowIDTableStaking.NodeInfo(nodeID: nodeStaker.id)

        assert (
            nodeInfo.role == NodeRole.Consensus.rawValue,
            message: "Node operator must be a consensus node to get a DKG Participant object"
        )

        let dkgAdmin = self.borrowDKGAdmin()
        return <-dkgAdmin.createParticipant(nodeID: nodeStaker.id)
    }

    /// Returns the metadata that is able to be configured by the admin
    access(all) view fun getConfigMetadata(): Config {
        return self.configurableMetadata
    }

    /// Returns the config for epoch timing, which can be configured by the admin.
    /// Conceptually, this should be part of `Config`, however it was added later in an
    /// upgrade which requires new fields be specified separately from existing structs.
    access(all) fun getEpochTimingConfig(): EpochTimingConfig {
        return self.account.storage.copy<EpochTimingConfig>(from: /storage/flowEpochTimingConfig)!
    }

    /// The proposed Epoch counter is always the current counter plus 1
    access(all) view fun proposedEpochCounter(): UInt64 {
        return self.currentEpochCounter + 1 as UInt64
    }

    access(all) fun automaticRewardsEnabled(): Bool {
        return self.account.storage.copy<Bool>(from: /storage/flowAutomaticRewardsEnabled) ?? false
    }

    /// Gets the current amount of bonus tokens left to be destroyed
    /// Bonus tokens are tokens that were allocated as a decentralization incentive
    /// that are currently in the process of being destroyed. The presence of bonus
    /// tokens throws off the intended calculation for the FLOW inflation rate
    /// so they are not included in that calculation
    /// Eventually, all the bonus tokens will be destroyed and
    /// this will not be needed anymore
    access(all) fun getBonusTokens(): UFix64 {
        return self.account.storage.copy<UFix64>(from: /storage/FlowBonusTokenAmount)
                ?? 0.0
    }

    init (currentEpochCounter: UInt64,
          numViewsInEpoch: UInt64,
          numViewsInStakingAuction: UInt64,
          numViewsInDKGPhase: UInt64,
          numCollectorClusters: UInt16,
          FLOWsupplyIncreasePercentage: UFix64,
          randomSource: String,
          collectorClusters: [FlowClusterQC.Cluster],
          clusterQCs: [FlowClusterQC.ClusterQC],
          dkgPubKeys: [String]) {
        pre {
            FlowEpoch.isValidPhaseConfiguration(numViewsInStakingAuction, numViewsInDKGPhase, numViewsInEpoch):
                "Invalid startView and endView configuration"
        }

        self.configurableMetadata = Config(numViewsInEpoch: numViewsInEpoch,
                                           numViewsInStakingAuction: numViewsInStakingAuction,
                                           numViewsInDKGPhase: numViewsInDKGPhase,
                                           numCollectorClusters: numCollectorClusters,
                                           FLOWsupplyIncreasePercentage: FLOWsupplyIncreasePercentage)

        // Set a reasonable default for the epoch timing config targeting 1 block per second
        let defaultEpochTimingConfig = EpochTimingConfig(
            duration: numViewsInEpoch,
            refCounter: currentEpochCounter,
            refTimestamp: UInt64(getCurrentBlock().timestamp)+numViewsInEpoch)
        FlowEpoch.account.storage.save(defaultEpochTimingConfig, to: /storage/flowEpochTimingConfig)

        self.currentEpochCounter = currentEpochCounter
        self.currentEpochPhase = EpochPhase.STAKINGAUCTION
        self.adminStoragePath = /storage/flowEpochAdmin
        self.heartbeatStoragePath = /storage/flowEpochHeartbeat
        self.metadataStoragePath = /storage/flowEpochMetadata

        let epochMetadata: {UInt64: EpochMetadata} = {}

        self.account.storage.save(epochMetadata, to: self.metadataStoragePath)

        self.account.storage.save(<-create Admin(), to: self.adminStoragePath)
        self.account.storage.save(<-create Heartbeat(), to: self.heartbeatStoragePath)

        // Create a private capability to the staking admin and store it in a different path
        // On Mainnet and Testnet, the Admin resources are stored in the service account, rather than here.
        // As a default, we store both the admin resources, and the capabilities linking to those resources, in the same account.
        // This ensures that this constructor produces a state which is compatible with the system chunk
        // so that newly created networks are functional without additional resource manipulation.
        let stakingAdminCapability = self.account.capabilities.storage.issue<&FlowIDTableStaking.Admin>(FlowIDTableStaking.StakingAdminStoragePath)
        self.account.storage.save<Capability<&FlowIDTableStaking.Admin>>(stakingAdminCapability, to: /storage/flowStakingAdminEpochOperations)

        // Create a private capability to the qc admin
        // and store it in a different path
        let qcAdminCapability = self.account.capabilities.storage.issue<&FlowClusterQC.Admin>(FlowClusterQC.AdminStoragePath)
        self.account.storage.save<Capability<&FlowClusterQC.Admin>>(qcAdminCapability, to: /storage/flowQCAdminEpochOperations)

        // Create a private capability to the dkg admin
        // and store it in a different path
        let dkgAdminCapability = self.account.capabilities.storage.issue<&FlowDKG.Admin>(FlowDKG.AdminStoragePath)
        self.account.storage.save<Capability<&FlowDKG.Admin>>(dkgAdminCapability, to: /storage/flowDKGAdminEpochOperations)

        self.borrowStakingAdmin().startStakingAuction()

        let currentBlock = getCurrentBlock()

        let firstEpochMetadata = EpochMetadata(counter: self.currentEpochCounter,
                    seed: randomSource,
                    startView: currentBlock.view,
                    endView: currentBlock.view + self.configurableMetadata.numViewsInEpoch - 1,
                    stakingEndView: currentBlock.view + self.configurableMetadata.numViewsInStakingAuction - 1,
                    totalRewards: FlowIDTableStaking.getEpochTokenPayout(),
                    collectorClusters: collectorClusters,
                    clusterQCs: clusterQCs,
                    dkgKeys: dkgPubKeys)

        self.saveEpochMetadata(firstEpochMetadata)
    }
}
