

pub contract FlowQuorumCertificate {

    /// The list of nodes ID in each cluster
    access(self) var collectorClusters: [[String]]

    /// The votes for each cluster
    /// An array of arrays of signatures
    /// Similar to the collector Clusters, but only includes
    /// the signatures of the nodes instead of the IDs
    access(self) var clusterQCs: [[String]]

    /// Indicates if a node has voted in the current QC phase
    access(self) var hasVoted: {String: Bool}

    /// The resource that each collector node operator stores in their account
    pub resource NodeQC {
        
        /// Allows a node to submit their QC vote during the voting phase
        /// and sets their status as hasVoted
        pub fun submitQCVote(id: String, signature: String) {
            pre {
                FlowQuorumCertificate.hasVoted[id] == nil: "Node cannot vote twice"
                signature.length > 0: "Signature cannot be empty"
                FlowIdentityTable.getAllProposedNodeInfo()[id] != nil: "Node ID must be proposed for the next epoch"
            }

            var clusterIndex = 0

            /// iterate through all the clusters to ensure 
            /// That this node is allowed to vote
            for cluster in FlowQuorumCertificate.collectorClusters {
                for node in cluster {
                    if id == node {
                        break
                    }
                }
                clusterIndex = clusterIndex + 1
            }

            /// Only record the vote if the nodeID was found
            if clusterIndex < FlowQuorumCertificate.collectorClusters.length {
                FlowQuorumCertificate.clusterQCs[clusterIndex].append(signature)

                FlowQuorumCertificate.hasVoted[id] = true
            } 
        }

    }

    /// Admin resource that has control to reset the voting field
    /// and clusters field
    pub resource Admin {

        /// Clear the voting field so that it can be used in the current epoch
        pub fun resetQCVoting() {
            FlowQuorumCertificate.clusterQCs = []
            FlowQuorumCertificate.hasVoted = {}
        }

        /// Overwrite the collector clusters record with the clusters
        /// for the next epoch
        pub fun setCollectorClusters(newClusters: [[String]]) {
            pre {
                newClusters.length > 0: "New Clusters cannot be empty"
            }
            FlowQuorumCertificate.collectorClusters = newClusters
        }

        pub fun createQCObject(): @NodeQC {
            return <-create NodeQC()
        }

        /// Get all the QC votes for a specific cluster
        pub fun getAllQCVotesInCluster(_ clusterIndex: Int): [String]? {
            if clusterIndex > FlowQuorumCertificate.clusterQCs.length - 1 {
                return nil
            }
            return FlowQuorumCertificate.clusterQCs[clusterIndex]
        }

        pub fun checkQuorum(clusterIndex: Int): Bool {
            // query the identity table. make sure that there is 2/3 weight for each collecor cluster
            
        }
    }

    /// Return the collector cluster IDs
    pub fun getCollectorClusters(): [[String]] {
        return self.collectorClusters
    }

    /// Return all the QC votes for all the clusters
    pub fun getAllQCVotes(): [[String]] {
        return self.clusterQCs
    }
    
    init() {
        self.clusterQCs = []
        self.collectorClusters = []
        self.hasVoted = {}

        self.account.save(<-create Admin(), to: /storage/flowQCAdmin)
        self.account.link<&Admin>(/public/flowQCAdmin, target: /storage/flowQCAdmin)
    }

}
 