
// Manages the process of collecting votes for the root quorum certificate of the upcoming
// epoch for all collection node clusters assigned for the upcoming epoch.
//
// This contract is a member of a series of epoch smart contracts which coordinates the 
// process of transitioning between epochs in Flow.
pub contract EpochClusterQCs {

    // ================================================================================
    // CONTRACT VARIABLES
    // ================================================================================

    // Indicates whether votes are currently being collected.
    // If false, no node operator will be able to submit votes
    pub var inProgress: Bool

    // The collection node clusters for the current epoch
    access(account) var clusters: [Cluster]

    // Votes that nodes claim at the beginning of each EpochSetup phase
    access(account) var generatedVotes: {String: Vote}

    // Votes submitted per cluster
    access(account) var votesByCluster: {UInt16: [Vote]}

    // Indicates if a voter resource has already been claimed by a node ID
    access(account) var voterClaimed: {String: Bool}

    // ================================================================================
    // CONTRACT CONSTANTS
    // ================================================================================

    // Canonical paths for admin and voter resources
    pub let AdminStoragePath: Path
    pub let VoterStoragePath: Path

    // Represents a collection node cluster for a given epoch. 
    pub struct Cluster {

        // The IDs of the nodes in the cluster.
        pub let nodeIDs: [String]

        // The index of the cluster within the cluster assignment. This uniquely identifies
        // a cluster for a given epoch
        pub let index: UInt16

        pub fun size(): UInt16 {
            return UInt16(self.nodeIDs.length) 
        }

        // Returns the minimum number of votes required in order to be able to generate a
        // valid quorum certificate for this cluster.
        pub fun voteThreshold(): UInt16 {
            return self.size() * UInt16(2) / UInt16(3) + UInt16(1)
        }

        init(index: UInt16, nodeIDs: [String]) {
            self.index = index
            self.nodeIDs = nodeIDs
        }
    }

    // Vote represents a vote from one collection node. It simply contains a string with an
    // encoded representation of the vote. Votes are aggregated to build quorum certificates;
    // eventually we may want to do the aggregation and validate votes within the smart
    // contract, but in the meantime the vote contents are opaque here.
    pub struct Vote {
        pub var nodeID: String
        pub(set) var raw: String?
        pub(set) var clusterIndex: UInt16

        init(nodeID: String, clusterIndex: UInt16) {
            pre {
                nodeID.length == 32: "Voter ID must be a valid node ID"
            }
            self.raw = nil
            self.nodeID = nodeID
            self.clusterIndex = clusterIndex
        }
    }

    // The Voter resource is generated for each collection node after they register.
    // Each resource instance is good for all future potential epochs, but will
    // only be valid if the node operator has been confirmed as a collector node for the next epoch.
    pub resource Voter {

        pub let nodeID: String

        pub var currentVote: Vote?

        // Returns whether this voter has successfully submitted a vote for this epoch.
        pub fun voted(): Bool {
            if EpochClusterQCs.generatedVotes[self.nodeID] == nil {
                return true
            } else {
                return false
            }
        }

        // Submits the given vote. Can be called only once. 
        pub fun vote(raw: String) {
            pre {
                raw.length > 0: "Vote must not be empty"
                EpochClusterQCs.generatedVotes[self.nodeID] != nil
            }

            let vote = EpochClusterQCs.generatedVotes[self.nodeID]!

            vote.raw = raw

            EpochClusterQCs.votesByCluster[vote.clusterIndex]!.append(vote)
        }

        init(nodeID: String) {
            pre {
                !EpochClusterQCs.voterClaimed[nodeID]!: "Cannot create a Voter resource for a node ID that has already been claimed"
            }
            self.nodeID = nodeID
            self.currentVote = nil
            EpochClusterQCs.voterClaimed[nodeID] = true
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
            EpochClusterQCs.inProgress = true
            EpochClusterQCs.clusters = clusters
            EpochClusterQCs.generatedVotes = {}
            EpochClusterQCs.votesByCluster = {}

            var clusterIndex: UInt16 = 0
            for cluster in clusters {

                // Clear all the clusters
                EpochClusterQCs.votesByCluster[clusterIndex] = []

                // Create a new Vote struct for each participating node
                for nodeID in cluster.nodeIDs {
                    EpochClusterQCs.generatedVotes[nodeID] = Vote(nodeID: nodeID, clusterIndex: clusterIndex)
                }

                clusterIndex = clusterIndex + UInt16(1)
            }
        }

        // Stops voting for the current epoch. Can only be called once a 2/3 
        // majority of each cluster has submitted a vote. 
        pub fun stopVoting() {
            pre {
                !EpochClusterQCs.votingCompleted(): "voting must be complete before it can be stopped"
            }
            EpochClusterQCs.inProgress = false
        }
    }

    // Gets all of the collector clusters for the current epoch
    pub fun getClusters(): [Cluster] {
        return self.clusters
    }

    // Returns true if we have collected enough votes for all clusters.
    pub fun votingCompleted(): Bool {

        for cluster in EpochClusterQCs.clusters {
            let votes = EpochClusterQCs.votesByCluster[cluster.index]!
            if UInt16(votes.length) < cluster.voteThreshold() {
                return false
            }
        }

        return true
    }

    init() {
        self.AdminStoragePath = /storage/flowEpochsQCAdmin
        self.VoterStoragePath = /storage/flowEpochsQCVoter

        self.inProgress = false
        self.votesByCluster = {} 
        
        self.clusters = []
        self.generatedVotes = {}
        self.voterClaimed = {}

        self.account.save(<-create Admin(), to: self.AdminStoragePath)
    }
}