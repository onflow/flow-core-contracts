package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (

	// Admin Transactions

	startVotingFilename  = "quorumCertificate/admin/start_voting.cdc"
	stopVotingFilename   = "quorumCertificate/admin/stop_voting.cdc"
	publishVoterFilename = "quorumCertificate/admin/publish_voter.cdc"

	// Node Transactions

	createVoterFilename = "quorumCertificate/create_voter.cdc"
	submitVoteFilename  = "quorumCertificate/submit_vote.cdc"

	// Scripts

	getClustersFilename        = "quorumCertificate/scripts/get_clusters.cdc"
	getClusterFilename         = "quorumCertificate/scripts/get_cluster.cdc"
	getVotingCompletedFilename = "quorumCertificate/scripts/get_voting_completed.cdc"
	getClusterVotesFilename    = "quorumCertificate/scripts/get_cluster_votes.cdc"

	getClusterVoteThresholdFilename = "quorumCertificate/scripts/get_cluster_vote_threshold.cdc"
	getClusterWeightFilename        = "quorumCertificate/scripts/get_cluster_weight.cdc"
	getClusterNodeWeightsFilename   = "quorumCertificate/scripts/get_cluster_node_weights.cdc"
	getNodeWeightFilename           = "quorumCertificate/scripts/get_node_weight.cdc"
	getNodeHasVotedFilename         = "quorumCertificate/scripts/get_node_has_voted.cdc"
)

// Admin Templates -----------------------------------------------------------

// GenerateStartVotingScript generates a script for the admin that starts voting
func GenerateStartVotingScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + startVotingFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateStopVotingScript generates a script for the admin that stops voting
func GenerateStopVotingScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + stopVotingFilename)

	return []byte(replaceAddresses(code, env))
}

func GeneratePublishVoterScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + publishVoterFilename)

	return []byte(replaceAddresses(code, env))
}

// Node Transactions

// GenerateCreateVoterScript generates a script that creates a qc node object
func GenerateCreateVoterScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + createVoterFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateSubmitVoteScript generates a script that submits a qc vote for a node
func GenerateSubmitVoteScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + submitVoteFilename)

	return []byte(replaceAddresses(code, env))
}

// Scripts

func GenerateGetClustersScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getClustersFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetClusterScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getClusterFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetClusterVoteThresholdScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getClusterVoteThresholdFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetClusterWeightScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getClusterWeightFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetClusterNodeWeightsScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getClusterNodeWeightsFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetNodeWeightScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getNodeWeightFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetVotingCompletedScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getVotingCompletedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetClusterVotesScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getClusterVotesFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetNodeHasVotedScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getNodeHasVotedFilename)

	return []byte(replaceAddresses(code, env))
}
