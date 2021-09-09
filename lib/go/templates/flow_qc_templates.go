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

	getQCEnabledScript = "quorumCertificate/scripts/get_qc_enabled.cdc"

	getClustersFilename        = "quorumCertificate/scripts/get_clusters.cdc"
	getClusterFilename         = "quorumCertificate/scripts/get_cluster.cdc"
	getClusterCompleteFilename = "quorumCertificate/scripts/get_cluster_complete.cdc"
	getVotingCompletedFilename = "quorumCertificate/scripts/get_voting_completed.cdc"
	getClusterVotesFilename    = "quorumCertificate/scripts/get_cluster_votes.cdc"

	getClusterVoteThresholdFilename   = "quorumCertificate/scripts/get_cluster_vote_threshold.cdc"
	getClusterWeightFilename          = "quorumCertificate/scripts/get_cluster_weight.cdc"
	getClusterNodeWeightsFilename     = "quorumCertificate/scripts/get_cluster_node_weights.cdc"
	getNodeWeightFilename             = "quorumCertificate/scripts/get_node_weight.cdc"
	getVoterIsRegisteredFilename      = "quorumCertificate/scripts/get_voter_is_registered.cdc"
	getNodeHasVotedFilename           = "quorumCertificate/scripts/get_node_has_voted.cdc"
	generateQuorumCertificateFilename = "quorumCertificate/scripts/generate_quorum_certificate.cdc"
)

// Admin Templates -----------------------------------------------------------

// GenerateStartVotingScript generates a script for the admin that starts voting
func GenerateStartVotingScript(env Environment) []byte {
	code := assets.MustAssetString(startVotingFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateStopVotingScript generates a script for the admin that stops voting
func GenerateStopVotingScript(env Environment) []byte {
	code := assets.MustAssetString(stopVotingFilename)

	return []byte(replaceAddresses(code, env))
}

func GeneratePublishVoterScript(env Environment) []byte {
	code := assets.MustAssetString(publishVoterFilename)

	return []byte(replaceAddresses(code, env))
}

// Node Transactions

// GenerateCreateVoterScript generates a script that creates a qc node object
func GenerateCreateVoterScript(env Environment) []byte {
	code := assets.MustAssetString(createVoterFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateSubmitVoteScript generates a script that submits a qc vote for a node
func GenerateSubmitVoteScript(env Environment) []byte {
	code := assets.MustAssetString(submitVoteFilename)

	return []byte(replaceAddresses(code, env))
}

// Scripts

func GenerateGetQCEnabledScript(env Environment) []byte {
	code := assets.MustAssetString(getQCEnabledScript)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetClustersScript(env Environment) []byte {
	code := assets.MustAssetString(getClustersFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetClusterScript(env Environment) []byte {
	code := assets.MustAssetString(getClusterFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetClusterCompleteScript(env Environment) []byte {
	code := assets.MustAssetString(getClusterCompleteFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetClusterVoteThresholdScript(env Environment) []byte {
	code := assets.MustAssetString(getClusterVoteThresholdFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetClusterWeightScript(env Environment) []byte {
	code := assets.MustAssetString(getClusterWeightFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetClusterNodeWeightsScript(env Environment) []byte {
	code := assets.MustAssetString(getClusterNodeWeightsFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetNodeWeightScript(env Environment) []byte {
	code := assets.MustAssetString(getNodeWeightFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetVotingCompletedScript(env Environment) []byte {
	code := assets.MustAssetString(getVotingCompletedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetClusterVotesScript(env Environment) []byte {
	code := assets.MustAssetString(getClusterVotesFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetVoterIsRegisteredScript(env Environment) []byte {
	code := assets.MustAssetString(getVoterIsRegisteredFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetNodeHasVotedScript(env Environment) []byte {
	code := assets.MustAssetString(getNodeHasVotedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGenerateQuorumCertificateScript(env Environment) []byte {
	code := assets.MustAssetString(generateQuorumCertificateFilename)

	return []byte(replaceAddresses(code, env))
}
