
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
    pub var inProgress: Bool

    // Indicates which epoch we are collecting votes for.
    // NOTE: Since we prepare for an epoch before it begins, this will be one ahead of the
    // current epoch.
    pub var epoch: UInt64

    // The collection node clusters for the current epoch
    pub var clusters: [Cluster]

    // Votes submitted per cluster
    pub var votesByCluster: {UInt16: [Vote]}

    // ================================================================================
    // CONTRACT CONSTANTS
    // ================================================================================

    // Canonical paths for various resources and capabilities.
    pub let AdminStoragePath: Path
    pub let AdminCapabilityPath: Path
    pub let VoterStoragePath: Path
    pub let VoterCapabilityPath: Path

    // Returns true if we have collected enough votes for all clusters.
    pub fun votingCompleted(): Bool {

        for cluster in EpochClusterQCs.clusters {
            let votes = EpochClusterQCs.votesByCluster[cluster.index]!
            if UInt16(votes.length) < cluster.voteThreshold() {
                return false
            }
        }

        return false
    }

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
        pub let nodeID: String
        pub let raw: String

        init(raw: String, voter: String) {
            self.raw = raw
            self.nodeID = voter
        }
    }

    // The Voter resource is generated for each collection node once they are confirmed 
    // as a participant in an upcoming epoch. Each resource instance is only good for one
    // vote submission within one epoch. 
    pub resource Voter {
        pub let nodeID: String
        pub let clusterIndex: UInt16
        pub let epoch: UInt64

        // Returns whether this voter has successfully submitted a vote for this epoch.
        pub fun voted(): Bool {
            let votes = EpochClusterQCs.votesByCluster[self.clusterIndex]!
            for vote in votes {
                if vote.nodeID == self.nodeID {
                    return true
                }
            }
            return false
        }

        // Submits the given vote. Can be called only once. 
        pub fun vote(vote: Vote) {
            pre {
                self.epoch == EpochClusterQCs.epoch: "cannot vote for a different epoch"
                !self.voted(): "already voted - only one vote allowed per epoch"
            }
            EpochClusterQCs.votesByCluster[self.clusterIndex]!.append(vote)
        }

        init(nodeID: String, clusterIndex: UInt16, epoch: UInt64) {
            self.nodeID = nodeID
            self.epoch = epoch
            self.clusterIndex = clusterIndex
        }

    }

    // The Admin resource provides the ability to begin voting for an epoch. 
    // TODO: I believe this can be replaced by account-scoped methods, as all
    // the epoch contracts should be deployed to the same (service) account.
    pub resource Admin {

        // Configures the contract for the next epoch's clusters. Returns a list
        // of Voter resources, one for each collection node in the next epoch.
        //
        // NOTE: This will be called by the top-level FlowEpochs contract upon
        // transitioning to the Epoch Setup Phase. That contract will be 
        // responsible for passing along each Voter resource to the account of
        // each node operator.
        //
        // CAUTION: calling this erases the votes for the current/previous epoch.
        pub fun startVoting(epoch: UInt64, clusters: [Cluster]): @[Voter] {
            EpochClusterQCs.inProgress = true
            EpochClusterQCs.epoch = epoch
            EpochClusterQCs.clusters = clusters

            let voters: @[Voter] <- []
            // TODO: can you iterate the index+value within the for loop
            var clusterIndex: UInt16 = 0
            for cluster in clusters {
                for nodeID in cluster.nodeIDs {
                    voters.append(<- create Voter(nodeID: nodeID, clusterIndex: clusterIndex, epoch: epoch))
                }
                clusterIndex = clusterIndex + UInt16(1)
            }
            return <-voters
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

    pub resource interface QCVoterReceiver {
        pub fun setVoter(voter: @EpochClusterQCs.Voter)
    }

    // Enables node operators to receive Voter resources for an upcoming epoch
    // from the epoch smart contract.
    // 
    // TODO: Get some insight on the best way to do this. The desired behaviour
    // is that a node operator submits one transaction that sets up their account
    // for "node operation". After this setup is complete, the Epoch smart contract
    // should be able to insert the appropriate resources to the operator's account
    // without any action by that account. Essentially once that account needs to
    // use eg. a Voter resource, the appropriate resource should already have been
    // inserted by the Epoch contract.
    pub resource QCVoterStore: QCVoterReceiver {
        pub let nodeID: String
        pub var voter: @EpochClusterQCs.QCVoter?

        // Sets the Voter resource stored in the VoterStore, destroying the
        // current Voter, if one exists.
        //
        // TODO: check security assumptions - only code that has a QCVoter
        // resource is able to call this method.
        pub fun setVoter(voter: @EpochClusterQCs.QCVoter) {
            pre {
                voter.nodeID == self.nodeID: "only accept our voter"
            }
            let previous <- self.voter <- voter
            destroy previous
        }

        // VoterStore always starts out empty.
        init(nodeID: String) {
            self.nodeID = nodeID
            self.voter <- nil
        }

        destroy() {
            destroy self.voter
        }
    }

    pub fun createAdmin(): @Admin {
        let admin <- create Admin()
        return <-admin
    }

    init() {
        self.AdminStoragePath = /storage/flowEpochsQCAdmin
        self.AdminCapabilityPath = /storage/flowEpochsQCAdminRef
        self.VoterStoragePath = /storage/flowEpochsQCVoter
        self.VoterCapabilityPath = /storage/flowEpochsQCVoterRef

        self.inProgress = false
        self.votesByCluster = {} 
        
        self.clusters = []
        self.epoch = 0
    }
}