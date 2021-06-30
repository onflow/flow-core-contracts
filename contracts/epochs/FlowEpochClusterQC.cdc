
/* 
*
*  Manages the process of collecting votes for the root quorum certificate of the upcoming
*  epoch for all collection node clusters assigned for the upcoming epoch.
*
*  When collector nodes are first confirmed, they can request a Voter object from this contract
*  They'll use this object for every subsequent epoch that they are a staked collector node.
*
*  At the beginning of each EpochSetup phase, the admin initializes this contract with
*  the collector clusters for the upcoming epoch. Each collector node has a single vote
*  that is allocated for them and they can only call their `vote` function once.
*  
*  Once all the collector nodes have received enough votes to surpass their weight threshold,
*  The QC generation phase is finished and the admin will end the voting.
*  At this point, anyone can query the voting information for the clusters 
*  by using the `getClusters` function.
* 
*  This contract is a member of a series of epoch smart contracts which coordinates the 
*  process of transitioning between epochs in Flow.
*/

import Crypto

pub contract FlowEpochClusterQC {

    // ================================================================================
    // CONTRACT VARIABLES
    // ================================================================================

    /// Indicates whether votes are currently being collected.
    /// If false, no node operator will be able to submit votes
    pub var inProgress: Bool

    /// The collection node clusters for the current epoch
    access(account) var clusters: [Cluster]

    /// Indicates if a voter resource has already been claimed by a node ID
    /// from the identity table contract
    /// Node IDs have to claim a voter once
    /// one node will use the same specific ID and Voter resource for all time
    /// `nil` means that there is no voting capability for the node ID
    /// false means that a voter capability for the ID, but it hasn't been claimed
    /// true means that the voter capability has been claimed by the node
    access(account) var voterClaimed: {String: Bool}

    /// Indicates what cluster a node is in for the current epoch
    /// Value is a cluster index
    access(contract) var nodeCluster: {String: UInt16}

    // ================================================================================
    // CONTRACT CONSTANTS
    // ================================================================================

    /// Canonical paths for admin and voter resources
    pub let AdminStoragePath: StoragePath
    pub let VoterStoragePath: StoragePath

    /// Represents a collection node cluster for a given epoch. 
    pub struct Cluster {

        /// The index of the cluster within the cluster assignment. This uniquely identifies
        /// a cluster for a given epoch
        pub let index: UInt16

        /// Weights for each nodeID in the cluster
        pub let nodeWeights: {String: UInt64}

        /// The total node weight of all the nodes in the cluster
        pub let totalWeight: UInt64

        /// Votes that nodes claim at the beginning of each EpochSetup phase
        /// Key is node ID from the identity table contract
        /// Vote resources without signatures for each node are stored here at the beginning of each epoch setup phase. 
        /// When a node submits a vote, they take it out of this map, add their signature, 
        /// then add it to the submitted vote list for their cluster.
        /// If a node has voted, their `signature` and `message` field will be non-nil
        /// If a node hasn't voted, their `signature` and `message` field will be nil
        pub var generatedVotes: {String: Vote}

        /// Tracks how much weight has been sent
        /// for each unique vote
        pub var uniqueVoteMessageTotalWeights: {String: UInt64}

        init(index: UInt16, nodeWeights: {String: UInt64}) {
            self.index = index
            self.nodeWeights = nodeWeights

            var totalWeight: UInt64 = 0
            for weight in nodeWeights.values {
                totalWeight = totalWeight + weight
            }
            self.totalWeight = totalWeight
            self.generatedVotes = {}
            self.uniqueVoteMessageTotalWeights = {}
        }

        pub fun size(): UInt16 {
            return UInt16(self.nodeWeights.length) 
        }

        /// Returns the minimum number of vote weight required in order to be able to generate a
        /// valid quorum certificate for this cluster.
        pub fun voteThreshold(): UInt64 {
            if self.totalWeight == 0 as UInt64 {
                return 0 as UInt64
            }

            let floorOneThird = self.totalWeight / UInt64(3) // integer division, includes floor

            var res = UInt64(2) * floorOneThird

            let divRemainder = self.totalWeight % UInt64(3)

            if divRemainder <= UInt64(1) {
                res = res + UInt64(1)
            } else {
                res = res + divRemainder
            }

            return res
        }

        /// Returns the status of this cluster's QC process
        /// If there is a number of identical votes exceeding the `voteThreshold`,
        /// Then this cluster's QC generation is considered complete and this method returns 
        /// the vote that reached quorum
        /// If no vote is found to reach quorum, then `nil` is returned
        pub fun isComplete(): String? {
            var i = 0

            for message in self.uniqueVoteMessageTotalWeights.keys {
                if self.uniqueVoteMessageTotalWeights[message]! >= self.voteThreshold() {
                    return message
                }
            }
            return nil
        }
    }

    /// Vote represents a vote from one collection node. It simply contains a string with an
    /// encoded representation of the vote. Votes are aggregated to build quorum certificates;
    /// eventually we may want to do the aggregation and validate votes within the smart
    /// contract, but in the meantime the vote contents are opaque here.
    pub struct Vote {
        pub var nodeID: String
        pub(set) var signature: String?
        pub(set) var message: String?
        pub let clusterIndex: UInt16
        pub let weight: UInt64

        init(nodeID: String, clusterIndex: UInt16, voteWeight: UInt64) {
            pre {
                nodeID.length == 64: "Voter ID must be a valid length node ID"
            }
            self.signature = nil
            self.message = nil
            self.nodeID = nodeID
            self.clusterIndex = clusterIndex
            self.weight = voteWeight
        }
    }

    /// Represents the quorum certificate for a specific cluster
    /// and all the nodes/votes in the cluster
    pub struct ClusterQC {

        /// The index of the qc in the cluster record
        pub let index: UInt16

        /// The vote signatures from all the nodes in the cluster
        pub var voteSignatures: [String]

        /// The vote messages from all the nodes in the cluster
        pub var voteMessages: [String]

        /// The node IDs that correspond to each vote
        pub var voterIDs: [String]

        init(index: UInt16, signatures: [String], messages: [String], voterIDs: [String]) {
            self.index = index
            self.voteSignatures = signatures
            self.voteMessages = messages
            self.voterIDs = voterIDs
        }
    }

    /// The Voter resource is generated for each collection node after they register.
    /// Each resource instance is good for all future potential epochs, but will
    /// only be valid if the node operator has been confirmed as a collector node for the next epoch.
    pub resource Voter {

        pub let nodeID: String

        pub var stakingKey: String

        init(nodeID: String, stakingKey: String) {
            pre {
                !FlowEpochClusterQC.voterIsClaimed(nodeID): "Cannot create a Voter resource for a node ID that has already been claimed"
            }

            self.nodeID = nodeID
            self.stakingKey = stakingKey
            FlowEpochClusterQC.voterClaimed[nodeID] = true
        }

        destroy () {
            FlowEpochClusterQC.voterClaimed[self.nodeID] = nil
        }

        /// Submits the given vote. Can be called only once per epoch
        pub fun vote(voteSignature: String, voteMessage: String) {
            pre {
                FlowEpochClusterQC.inProgress: "Voting phase is not in progress"
                voteSignature.length > 0: "Vote signature must not be empty"
                voteMessage.length > 0: "Vote message must not be empty"
                !FlowEpochClusterQC.nodeHasVoted(self.nodeID): "Vote must not have been cast already"
            }

            // Get the public key object from the stored key
            let publicKey = PublicKey(
                publicKey: self.stakingKey.decodeHex(),
                signatureAlgorithm: SignatureAlgorithm.BLS_BLS12_381
            )

            // Check to see that the signature on the message is valid 
            let isValid = publicKey.verify(
                signature: voteSignature.decodeHex(),
                signedData: voteMessage.decodeHex(),
                domainSeparationTag: "FLOW-V0.0_Collector-Vote",
                hashAlgorithm: HashAlgorithm.KMAC128_BLS_BLS12_381
            )

            // Assert the validity
            assert (
                isValid,
                message: "Vote Signature cannot be verified"
            )

            let clusterIndex = FlowEpochClusterQC.nodeCluster[self.nodeID]
                ?? panic("This node cannot vote during the current epoch")

            let cluster = FlowEpochClusterQC.clusters[clusterIndex]!

            let vote = cluster.generatedVotes[self.nodeID]!

            vote.signature = voteSignature
            vote.message = voteMessage

            let totalWeight = cluster.uniqueVoteMessageTotalWeights[voteMessage] ?? (0 as UInt64)
            var newWeight = totalWeight + vote.weight
            cluster.uniqueVoteMessageTotalWeights[voteMessage] = newWeight

            cluster.generatedVotes[self.nodeID] = vote
            FlowEpochClusterQC.clusters[clusterIndex] = cluster
        }

    }

    /// The Admin resource provides the ability to create to Voter resource objects,
    /// begin voting, and end voting for an epoch
    pub resource Admin {

        /// Creates a new Voter resource for a collection node
        pub fun createVoter(nodeID: String, stakingKey: String): @Voter {
            return <-create Voter(nodeID: nodeID, stakingKey: stakingKey)
        }

        /// Configures the contract for the next epoch's clusters
        ///
        /// NOTE: This will be called by the top-level FlowEpochs contract upon
        /// transitioning to the Epoch Setup Phase.
        ///
        /// CAUTION: calling this erases the votes for the current/previous epoch.
        pub fun startVoting(clusters: [Cluster]) {
            FlowEpochClusterQC.inProgress = true
            FlowEpochClusterQC.clusters = clusters

            var clusterIndex: UInt16 = 0
            for cluster in clusters {

                // Create a new Vote struct for each participating node
                for nodeID in cluster.nodeWeights.keys {
                    cluster.generatedVotes[nodeID] = Vote(nodeID: nodeID, clusterIndex: clusterIndex, voteWeight: cluster.nodeWeights[nodeID]!)
                    FlowEpochClusterQC.nodeCluster[nodeID] = clusterIndex                   
                }
                
                FlowEpochClusterQC.clusters[clusterIndex] = cluster
                clusterIndex = clusterIndex + UInt16(1)
            }
        }

        /// Stops voting for the current epoch. Can only be called once a 2/3 
        /// majority of each cluster has submitted a vote. 
        pub fun stopVoting() {
            pre {
                FlowEpochClusterQC.votingCompleted(): "Voting must be complete before it can be stopped"
            }
            FlowEpochClusterQC.inProgress = false
        }

        /// Force a stop of the voting period
        /// Should only be used if the protocol halts and needs to be reset
        pub fun forceStopVoting() {
            FlowEpochClusterQC.inProgress = false
        }
    }

    /// Returns a boolean telling if the voter is registered for the current voting phase
    pub fun voterIsRegistered(_ nodeID: String): Bool {
        return FlowEpochClusterQC.nodeCluster[nodeID] != nil
    }

    /// Returns a boolean telling if the node has claimed their `Voter` resource object
    /// The object can only be claimed once, but if the node destroys their `Voter` object,
    /// It could be claimed again
    pub fun voterIsClaimed(_ nodeID: String): Bool {
        return FlowEpochClusterQC.voterClaimed[nodeID] != nil
    }

    /// Returns whether this voter has successfully submitted a vote for this epoch.
    pub fun nodeHasVoted(_ nodeID: String): Bool {

        if let clusterIndex = FlowEpochClusterQC.nodeCluster[nodeID] {

            let cluster = FlowEpochClusterQC.clusters[clusterIndex]

            if cluster.nodeWeights[nodeID] != nil {
                return cluster.generatedVotes[nodeID]!.signature != nil
            }
        }

        return false
    }

    /// Gets all of the collector clusters for the current epoch
    pub fun getClusters(): [Cluster] {
        return self.clusters
    }

    /// Returns true if we have collected enough votes for all clusters.
    pub fun votingCompleted(): Bool {
        for cluster in FlowEpochClusterQC.clusters {
            if cluster.isComplete() == nil {
                return false
            }
        }
        return true
    }

    init() {
        self.AdminStoragePath = /storage/flowEpochsQCAdmin
        self.VoterStoragePath = /storage/flowEpochsQCVoter

        self.inProgress = false 
        
        self.clusters = []
        self.voterClaimed = {}
        self.nodeCluster = {}

        self.account.save(<-create Admin(), to: self.AdminStoragePath)
    }
}