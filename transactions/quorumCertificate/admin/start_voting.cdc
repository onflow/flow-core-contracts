import FlowClusterQC from 0xQCADDRESS

// Test transaction for the QC admin to start the QC voting period
// with a array of collector node clusters

// Arguments:
// 
// indices: An array of cluster indices
// clusterNodeIDs: Array of arrays of all the node IDs in each cluster
// nodeWeights: Array of arrays of node weights in each cluster

transaction(indices: [UInt16], clusterNodeIDs: [[String]], nodeWeights: [[UInt64]]) {

    prepare(signer: AuthAccount) {

        // Borrow a reference to the QC admin object
        let adminRef = signer.borrow<&FlowClusterQC.Admin>(from: FlowClusterQC.AdminStoragePath)
            ?? panic("Could not borrow reference to qc admin")

        let clusters: [FlowClusterQC.Cluster] = []
        
        // Iterate through each cluster and construct a Cluster object
        for index in indices {

            let nodeWeightsDictionary: {String: UInt64} = {}
            var i = 0

            // Set each node's id and weight
            // Calculate the total weight for each cluster
            for nodeID in clusterNodeIDs[index] {
                let nodes = nodeWeights[index]
                let nodeWeight = nodes[i]

                nodeWeightsDictionary[nodeID] = nodeWeight

                i = i + 1
            }

            clusters.append(FlowClusterQC.Cluster(index: index, nodeWeights: nodeWeightsDictionary))
        }

        // Start QC Voting with the supplied clusters
        adminRef.startVoting(clusters: clusters)
    }
}