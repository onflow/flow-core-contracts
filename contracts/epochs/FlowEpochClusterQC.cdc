
/* 
*
*  Manages the process of collecting votes for the root quorum certificate of the upcoming
*  epoch for all collection node clusters assigned for the upcoming epoch.
*
*  When collector nodes are first confirmed, they can request a voter object from this contract
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
pub contract FlowEpochClusterQC {

    // ================================================================================
    // CONTRACT VARIABLES
    // ================================================================================

    // Indicates whether votes are currently being collected.
    // If false, no node operator will be able to submit votes
    pub var inProgress: Bool

    // The collection node clusters for the current epoch
    access(account) var clusters: [Cluster]

    // Indicates if a voter resource has already been claimed by a node ID
    // from the identity table contract
    // Node IDs have to claim a voter capability every epoch
    // one node will use the same specific ID for all time, but will use a different Voter capability per epoch
    // `nil` means that there is no voting capability for the node ID
    // false means that a voter capability for the ID, but it hasn't been claimed
    // true means that the voter capability has been claimed by the node
    access(account) var voterClaimed: {String: Bool}

    // Votes that nodes claim at the beginning of each EpochSetup phase
    // Key is node ID from the identity table contract
    // Vote resources without signatures for each node are stored here at the beginning of each epoch setup phase. 
    // When a node submits a vote, they take it out of this map, add their signature, 
    // then add it to the submitted vote list for their cluster.
    access(account) var generatedVotes: {String: Vote}

    // ================================================================================
    // CONTRACT CONSTANTS
    // ================================================================================

    // Canonical paths for admin and voter resources
    pub let AdminStoragePath: Path
    pub let VoterStoragePath: Path

    // Represents a collection node cluster for a given epoch. 
    pub struct Cluster {

        // The index of the cluster within the cluster assignment. This uniquely identifies
        // a cluster for a given epoch
        pub let index: UInt16

        pub let nodeWeights: {String: UInt64}

        // The total node weight of all the nodes in the cluster
        pub let totalWeight: UInt64

        // Votes submitted for the cluster
        access(contract) var votes: [Vote]

        pub fun size(): UInt16 {
            return UInt16(self.nodeWeights.length) 
        }

        // Returns the minimum number of vote weight required in order to be able to generate a
        // valid quorum certificate for this cluster.
        pub fun voteThreshold(): UInt64 {
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

        init(index: UInt16, nodeWeights: {String: UInt64}, totalWeight: UInt64) {
            self.index = index
            self.nodeWeights = nodeWeights
            self.totalWeight = totalWeight
            self.votes = []
        }
    }

    // Vote represents a vote from one collection node. It simply contains a string with an
    // encoded representation of the vote. Votes are aggregated to build quorum certificates;
    // eventually we may want to do the aggregation and validate votes within the smart
    // contract, but in the meantime the vote contents are opaque here.
    pub struct Vote {
        pub var nodeID: String
        pub(set) var raw: String?
        pub let clusterIndex: UInt16
        pub let voteWeight: UInt64

        init(nodeID: String, clusterIndex: UInt16, voteWeight: UInt64) {
            pre {
                nodeID.length == 64: "Voter ID must be a valid node ID"
            }
            self.raw = nil
            self.nodeID = nodeID
            self.clusterIndex = clusterIndex
            self.voteWeight = voteWeight
        }
    }

    // The Voter resource is generated for each collection node after they register.
    // Each resource instance is good for all future potential epochs, but will
    // only be valid if the node operator has been confirmed as a collector node for the next epoch.
    pub resource Voter {

        pub let nodeID: String

        // Submits the given vote. Can be called only once per epoch
        pub fun vote(_ raw: String) {
            pre {
                raw.length > 0: "Vote must not be empty"
                FlowEpochClusterQC.nodeHasVoted(self.nodeID) != nil: "Vote must not have been cast already"
            }

            let vote = FlowEpochClusterQC.generatedVotes[self.nodeID]!

            vote.raw = raw

            FlowEpochClusterQC.clusters[vote.clusterIndex].votes.append(vote)

            FlowEpochClusterQC.generatedVotes[self.nodeID] = nil

        }

        init(nodeID: String) {
            pre {
                FlowEpochClusterQC.voterIsRegistered(nodeID): "Cannot create a Voter for a node ID that hasn't been registered"
                !FlowEpochClusterQC.voterIsClaimed(nodeID)!: "Cannot create a Voter resource for a node ID that has already been claimed"
            }
            self.nodeID = nodeID
            FlowEpochClusterQC.voterClaimed[nodeID] = true
        }

    }

    // The Admin resource provides the ability to begin and end voting for an epoch
    pub resource Admin {

        /// Creates a new Voter resource for a collection node
        pub fun createVoter(nodeID: String): @Voter {
            return <-create Voter(nodeID: nodeID)
        }

        // Configures the contract for the next epoch's clusters
        //
        // NOTE: This will be called by the top-level FlowEpochs contract upon
        // transitioning to the Epoch Setup Phase.
        //
        // CAUTION: calling this erases the votes for the current/previous epoch.
        pub fun startVoting(clusters: [Cluster]) {
            FlowEpochClusterQC.inProgress = true
            FlowEpochClusterQC.clusters = clusters
            FlowEpochClusterQC.generatedVotes = {}
            FlowEpochClusterQC.voterClaimed = {}

            var clusterIndex: UInt16 = 0
            for cluster in clusters {

                // Create a new Vote struct for each participating node
                for nodeID in cluster.nodeWeights.keys {
                    FlowEpochClusterQC.generatedVotes[nodeID] = Vote(nodeID: nodeID, clusterIndex: clusterIndex, voteWeight: cluster.nodeWeights[nodeID]!)
                    FlowEpochClusterQC.voterClaimed[nodeID] = false
                }

                clusterIndex = clusterIndex + UInt16(1)
            }
        }

        // Stops voting for the current epoch. Can only be called once a 2/3 
        // majority of each cluster has submitted a vote. 
        pub fun stopVoting() {
            pre {
                FlowEpochClusterQC.votingCompleted(): "Voting must be complete before it can be stopped"
            }
            FlowEpochClusterQC.inProgress = false
        }
    }

    pub fun voterIsRegistered(_ nodeID: String): Bool {
        return FlowEpochClusterQC.voterClaimed[nodeID] != nil
    }

    pub fun voterIsClaimed(_ nodeID: String): Bool? {
        return FlowEpochClusterQC.voterClaimed[nodeID]
    }

    // Returns whether this voter has successfully submitted a vote for this epoch.
    pub fun nodeHasVoted(_ nodeID: String): Bool {

        // Iterate through the clusters to find this voter
        for cluster in FlowEpochClusterQC.clusters {
            if cluster.nodeWeights[nodeID] != nil {
                return FlowEpochClusterQC.generatedVotes[nodeID] == nil
            }
        }

        // If the voter was not found, it means they are not it the current epoch
        // and therefore have not voted
        return false
    }

    // Gets all of the collector clusters for the current epoch
    pub fun getClusters(): [Cluster] {
        return self.clusters
    }

    // Returns true if we have collected enough votes for all clusters.
    pub fun votingCompleted(): Bool {

        for cluster in FlowEpochClusterQC.clusters {

            var voteWeightSum: UInt64 = 0
            for vote in cluster.votes {
                voteWeightSum = voteWeightSum + vote.voteWeight
            }

            if voteWeightSum < cluster.voteThreshold() {
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
        self.generatedVotes = {}
        self.voterClaimed = {}

        self.account.save(<-create Admin(), to: self.AdminStoragePath)
    }
}