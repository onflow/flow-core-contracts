package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (

	// Admin Transactions

	startDKGFilename           = "dkg/admin/start_dkg.cdc"
	nextPhaseFilename          = "dkg/admin/next_phase.cdc"
	stopDKGFilename            = "dkg/admin/stop_dkg.cdc"
	forceStopDKGFilename       = "dkg/admin/force_stop_dkg.cdc"
	setSafeThresholdFilename   = "dkg/admin/set_safe_threshold.cdc"
	publishParticipantFilename = "dkg/admin/publish_participant.cdc"

	// Node Transactions

	createParticipantFilename     = "dkg/create_participant.cdc"
	sendWhiteBoardMessageFilename = "dkg/send_whiteboard_message.cdc"
	sendFinalSubmissionFilename   = "dkg/send_final_submission.cdc"

	// Scripts

	getDKGEnabledFilename               = "dkg/scripts/get_dkg_enabled.cdc"
	getConsensusNodesFilename           = "dkg/scripts/get_consensus_nodes.cdc"
	getdkgCompletedFilename             = "dkg/scripts/get_dkg_completed.cdc"
	getWhiteBoardMessagesFilename       = "dkg/scripts/get_whiteboard_messages.cdc"
	getLatestMessagesFilename           = "dkg/scripts/get_latest_whiteboard_messages.cdc"
	getFinalSubmissionsFilename         = "dkg/scripts/get_final_submissions.cdc"
	getCanonicalFinalSubmissionFilename = "dkg/scripts/get_dkg_canonical_final_submission.cdc"
	getThresholdsFilename               = "dkg/scripts/get_thresholds.cdc"

	getNodeIsRegisteredFilename    = "dkg/scripts/get_node_is_registered.cdc"
	getNodeIsClaimedFilename       = "dkg/scripts/get_node_is_claimed.cdc"
	getNodeHasSubmittedFilename    = "dkg/scripts/get_node_has_submitted.cdc"
	getNodeFinalSubmissionFilename = "dkg/scripts/get_node_final_submission.cdc"
)

// Admin Templates -----------------------------------------------------------

// GenerateStartDKGScript generates a script for the admin that starts DKG
func GenerateStartDKGScript(env Environment) []byte {
	code := assets.MustAssetString(startDKGFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateStopDKGScript generates a script for the admin that stops DKG
func GenerateStopDKGScript(env Environment) []byte {
	code := assets.MustAssetString(stopDKGFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateForceStopDKGScript(env Environment) []byte {
	code := assets.MustAssetString(forceStopDKGFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateSetSafeThresholdScript generates a script for the admin
// to set a new threshold percentage for DKG completion
func GenerateSetSafeThresholdScript(env Environment) []byte {
	code := assets.MustAssetString(setSafeThresholdFilename)

	return []byte(replaceAddresses(code, env))
}

func GeneratePublishDKGParticipantScript(env Environment) []byte {
	code := assets.MustAssetString(publishParticipantFilename)

	return []byte(replaceAddresses(code, env))
}

// Node Transactions

// GenerateCreateDKGParticipantScript generates a script that creates a dkg node object
func GenerateCreateDKGParticipantScript(env Environment) []byte {
	code := assets.MustAssetString(createParticipantFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateSendDKGWhiteboardMessageScript generates a script that sends a dkg final submission for a node
func GenerateSendDKGWhiteboardMessageScript(env Environment) []byte {
	code := assets.MustAssetString(sendWhiteBoardMessageFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateSendDKGFinalSubmissionScript generates a script that sends a dkg final submission for a node
func GenerateSendDKGFinalSubmissionScript(env Environment) []byte {
	code := assets.MustAssetString(sendFinalSubmissionFilename)

	return []byte(replaceAddresses(code, env))
}

// Scripts

func GenerateGetDKGEnabledScript(env Environment) []byte {
	code := assets.MustAssetString(getDKGEnabledFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetConsensusNodesScript(env Environment) []byte {
	code := assets.MustAssetString(getConsensusNodesFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDKGCompletedScript(env Environment) []byte {
	code := assets.MustAssetString(getdkgCompletedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDKGWhiteBoardMessagesScript(env Environment) []byte {
	code := assets.MustAssetString(getWhiteBoardMessagesFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDKGLatestWhiteBoardMessagesScript(env Environment) []byte {
	code := assets.MustAssetString(getLatestMessagesFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDKGFinalSubmissionsScript(env Environment) []byte {
	code := assets.MustAssetString(getFinalSubmissionsFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDKGNodeIsRegisteredScript(env Environment) []byte {
	code := assets.MustAssetString(getNodeIsRegisteredFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDKGNodeIsClaimedScript(env Environment) []byte {
	code := assets.MustAssetString(getNodeIsClaimedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDKGNodeHasFinalSubmittedScript(env Environment) []byte {
	code := assets.MustAssetString(getNodeHasSubmittedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDKGNodeFinalSubmissionScript(env Environment) []byte {
	code := assets.MustAssetString(getNodeFinalSubmissionFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDKGCanonicalFinalSubmissionScript(env Environment) []byte {
	code := assets.MustAssetString(getCanonicalFinalSubmissionFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDKGThresholdsScript(env Environment) []byte {
	code := assets.MustAssetString(getThresholdsFilename)

	return []byte(replaceAddresses(code, env))
}
