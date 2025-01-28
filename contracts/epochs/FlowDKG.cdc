/* 
*
*  Manages the process of generating a group key with the participation of all the consensus nodes
*  for the upcoming epoch.
*
*  When consensus nodes are first confirmed, they can request a Participant object from this contract
*  They'll use this object for every subsequent epoch that they are a staked consensus node.
*
*  At the beginning of each EpochSetup phase, the admin initializes this contract with
*  the list of consensus nodes for the upcoming epoch. Each consensus node
*  can post as many messages as they want to the DKG "whiteboard" with the `Participant.postMessage()` method,
*  but each node can only submit a final submission once per epoch via the `Participant.sendFinalSubmission() method.
*  
*  Once a >50% threshold of consensus nodes have submitted the exact same set of keys,
*  the DKG phase is technically finished.
*  Anyone can query the state of the submissions with the FlowDKG.getFinalSubmissions()
*  or FlowDKG.dkgCompleted() methods.
*  Consensus nodes can continue to submit final messages even after the required amount have been submitted though.
* 
*  This contract is a member of a series of epoch smart contracts which coordinates the 
*  process of transitioning between epochs in Flow.
*/

access(all) contract FlowDKG {

    // ================================================================================
    // DKG EVENTS
    // ================================================================================

    /// Emitted when the admin enables the DKG
    access(all) event StartDKG()

    /// Emitted when the admin ends the DKG (one DKG instance).
    /// The event includes the canonical result submission if the DKG succeeded,
    /// or nil if the DKG failed or was stopped before completion.
    access(all) event EndDKG(finalSubmission: ResultSubmission?)

    /// Emitted when a consensus node has posted a message to the DKG whiteboard
    access(all) event BroadcastMessage(nodeID: String, content: String)

    // ================================================================================
    // CONTRACT VARIABLES
    // ================================================================================

    /// The length of keys that have to be submitted as a final submission
    access(all) let submissionKeyLength: Int

    /// Indicates if the DKG is enabled or not
    access(all) var dkgEnabled: Bool

    /// Indicates if a Participant resource has already been claimed by a node ID
    /// from the identity table contract
    /// Node IDs have to claim a participant once
    /// one node will use the same specific ID and Participant resource for all time
    /// `nil` or false means that there is no voting capability for the node ID
    /// true means that the participant capability has been claimed by the node
    access(account) var nodeClaimed: {String: Bool}

    /// Record of whiteboard messages for the current epoch
    /// This is reset at the beginning of every DKG instance (once per epoch)
    access(account) var whiteboardMessages: [Message]

    // DEPRECATED FIELDS (replaced by SubmissionTracker)
    access(account) var finalSubmissionByNodeID: {String: [String?]} // deprecated and unused
    access(account) var uniqueFinalSubmissions: [[String?]]          // deprecated and unused
    access(account) var uniqueFinalSubmissionCount: {Int: UInt64}    // deprecated and unused

    // ================================================================================
    // CONTRACT CONSTANTS
    // ================================================================================

    // Canonical paths for admin and participant resources
    access(all) let AdminStoragePath: StoragePath
    access(all) let ParticipantStoragePath: StoragePath
    access(all) let ParticipantPublicPath: PublicPath

    /// Struct to represent a single whiteboard message
    access(all) struct Message {

        /// The ID of the node who submitted the message
        access(all) let nodeID: String

        /// The content of the message
        /// We make no assumptions or assertions about the content of the message
        access(all) let content: String

        init(nodeID: String, content: String) {
            self.nodeID = nodeID
            self.content = content
        }
    }

    // Checks whether the ResultSubmission constructor arguments satisfy Invariant (1):
    //   (1) either all fields are nil (empty submission) or no fields are nil
    // A valid empty submission has all fields nil, and is used when the submittor locally failed the DKG.
    // All non-empty submissions must have all non-nil fields.
    access(all) view fun checkEmptySubmissionInvariant(groupPubKey: String?, pubKeys: [String]?, idMapping: {String:Int}?): Bool {
        // If any fields are nil, then this represents a empty submission and all fields must be nil
        if groupPubKey == nil && pubKeys == nil && idMapping == nil {
            return true
        }
        // Otherwise, all fields must be non-nil
        return groupPubKey != nil && pubKeys != nil && idMapping != nil 
    }

    // Checks the group public key (part of a ResultSubmission) for validity.
    // A valid public key in this context is either: (1) a hex-encoded 96 bytes, or (2) nil.
    access(all) view fun isValidGroupKey(_ groupKey: String?): Bool {
         if groupKey == nil {
            // By Invariant (1), This is a nil/empty submission (see checkEmptySubmissionInvariant)
            return true
        }
        return groupKey!.length == FlowDKG.submissionKeyLength
    }

    // Checks a list of participant public keys (part of a ResultSubmission) for validity.
    // A valid public key in this context is either: (1) a hex-encoded 96 bytes, or (2) nil.
    access(all) view fun isValidPubKeys(_ pubKeys: [String]?): Bool {
        if pubKeys == nil {
            // By Invariant (1), This is a nil/empty submission (see checkEmptySubmissionInvariant)
            return true
        }
        for key in pubKeys! {
            // keys must be exactly 96 bytes
             if key.length != FlowDKG.submissionKeyLength {
                 return false
             }
        }
        return true
    }

    // Checks that an id mapping (part of ResultSubmission) contains one entry per public key.
    access(all) view fun isValidIDMapping(pubKeys: [String]?, idMapping: {String: Int}?): Bool {
        if pubKeys == nil {
            // By Invariant (1), This is a nil/empty submission (see checkEmptySubmissionInvariant)
            return true
        }
        return pubKeys!.length == idMapping!.keys.length
    }

    // ResultSubmission represents a result submission from one DKG participant.
    // Each submission includes a group public key and an ordered list of participant public keys.
    // A submission may be empty, in which case all fields are nil - this is used to represent a local DKG failure.
    // All non-empty submission will have all non-nil, valid fields.
    // By convention, all keys are encoded as lowercase hex strings, though it is not enforced here.
    //
    // INVARIANTS:
    //  (1) either all fields are nil (empty submission) or no fields are nil
    //  (2) all key strings are the expected length for BLS public keys
    //  (3) all non-empty submissions have one participant key per node ID in idMapping
    access(all) struct ResultSubmission {
        // The group public key for the beacon committee resulting from the DKG.
        access(all) let groupPubKey: String?
        // An ordered list of individual public keys for the beacon committee resulting from the DKG.
        access(all) let pubKeys: [String]?
        // A mapping from node ID to DKG index.
        // There must be exactly one key per authorized DKG participant.
        // The set of values should form the set {0, 1, 2, ... n-1}, where n is the number of
        // authorized DKG participant, however this is not enforced here.
        access(all) let idMapping: {String:Int}?

        init(groupPubKey: String?, pubKeys: [String]?, idMapping: {String:Int}?) {
            pre {
                FlowDKG.checkEmptySubmissionInvariant(groupPubKey: groupPubKey, pubKeys: pubKeys, idMapping: idMapping): 
                    "FlowDKG.ResultSubmission.init: violates empty submission invariant - ResultSubmission fields must be all nil or all non-nil"
                FlowDKG.isValidGroupKey(groupPubKey):
                    "FlowDKG.ResultSubmission.init: invalid group key - must be nil or hex-encoded 96-byte string"
                FlowDKG.isValidPubKeys(pubKeys):
                    "FlowDKG.ResultSubmission.init: invalid participant key - must be nil or hex-encoded 96-byte string"
                FlowDKG.isValidIDMapping(pubKeys: pubKeys, idMapping: idMapping):
                    "FlowDKG.ResultSubmission.init: invalid ID mapping - must be same size as pubKeys"
            }
            self.groupPubKey = groupPubKey
            self.pubKeys = pubKeys
            self.idMapping = idMapping
        }

        // Returns true if this ResultSubmission instance represents an empty submission.
        // Since the constructor enforces invariant (1), we only need to check one field.
        access(all) view fun isEmpty(): Bool {
            return self.groupPubKey == nil
        }

        // Checks whether the input is equivalent to this ResultSubmission.
        // Submissions must have identical keys, in the same order, and identical index mappings.
        // Empty submissions are considered equal.
        access(all) fun equals(_ other: FlowDKG.ResultSubmission): Bool {
            if self.groupPubKey != other.groupPubKey {
                return false
            }
            if self.pubKeys != other.pubKeys {
                return false
            }
            if self.idMapping != other.idMapping {
                return false
            }
            return true
        }

        // Checks whether this ResultSubmission COULD BE a valid submission for the given DKG committee.
        access(all) view fun isValidForCommittee(authorized: [String]): Bool {
            if self.isEmpty() {
                return true
            }

            // Must have one public key per DKG participant
            if authorized.length != self.pubKeys!.length {
                return false
            }
            // Must have a DKG index mapped for each DKG participant
            for nodeID in authorized {
                if self.idMapping![nodeID] == nil {
                    return false
                }
            }
            return true
        }
    }

    // SubmissionTracker tracks all state related to result submissions.
    // It is intended for internal use by the FlowDKG contract as a private singleton.
    // Future modifications MUST NOT make this singleton instance of SubmissionTracker publicly accessible.
    access(all) struct SubmissionTracker {
        // Set of authorized participants for this DKG instance (the "DKG committee")
        // Keys are node IDs, as registered in the FlowIDTableStaking contract.
        // NOTE: all values are true - this is structured as a map for O(1) lookup; conceptually it is a set.
        access(all) var authorized: {String: Bool}
        // List of unique submissions, in submission order
        access(all) var uniques: [FlowDKG.ResultSubmission]
        // Maps node ID of authorized participants to an index within "uniques"
        access(all) var byNodeID: {String: Int}
        // Maps index within "uniques" to count of submissions
        access(all) var counts: {Int: UInt64}

        init() {
            self.authorized = {}
            self.uniques = []
            self.byNodeID = {}
            self.counts = {}
        }

        // Called each time a new DKG instance starts, to reset SubmissionTracker state.
        // NOTE: we could also re-instantiate a new SubmissionTracker each time, but this pattern makes
        // storage management simpler because you never load/save the tracker after construction or upgrade.
        access(all) fun reset(nodeIDs: [String]) {
            self.authorized = {}
            self.uniques = []
            self.byNodeID = {}
            self.counts = {}
            for nodeID in nodeIDs {
                self.authorized[nodeID] = true
            }
        }

        // Adds the result submission for the DKG participant identified by nodeID.
        // The DKG participant must be authorized for the current epoch, and each participant may submit only once.
        // CAUTION: This method should only be called by Participant, which enforces that Participant.nodeID is passed in.
        access(all) fun addSubmission(nodeID: String, submission: ResultSubmission) {
            pre {
                self.authorized[nodeID] != nil:
                    "FlowDKG.addSubmission: Submittor (node ID: "
                        .concat(nodeID)
                        .concat(") is not authorized for this DKG instance.")
                self.byNodeID[nodeID] == nil:
                    "FlowDKG.SubmissionTracker.addSubmission: Submittor (node ID: "
                        .concat(nodeID)
                        .concat(") may only submit once and has already submitted")
                submission.isValidForCommittee(authorized: self.authorized.keys):
                    "FlowDKG.SubmissionTracker.addSubmission: Submission must contain exactly one public key per authorized participant"
            }

            // 1) Check whether this submission is equivalent to an existing submission (typical case)
            var submissionIndex = 0
            while submissionIndex < self.uniques.length {
                if submission.equals(self.uniques[submissionIndex]) {
                    self.byNodeID[nodeID] = submissionIndex
                    self.counts[submissionIndex] = self.counts[submissionIndex]! + 1 
                    return
                }
                submissionIndex = submissionIndex + 1
            }

            // 2) This submission differs from all existing submissions (or is the first), so add a new unique submission.
            // NOTE: at this point submissionIndex == self.uniques.length (the index of the submission we are adding)
            self.uniques.append(submission)
            self.byNodeID[nodeID] = submissionIndex
            self.counts[submissionIndex] = 1
        }

        // Returns the non-empty result which was submitted by at least threshold+1 DKG participants.
        // If no result received enough submissions, returns nil.
        // Callers should use a threshold that is greater than or equal to half the DKG committee size.
        access(all) view fun submissionExceedsThreshold(_ threshold: UInt64): ResultSubmission? {
            post {
                result == nil || !result!.isEmpty():
                    "FlowDKG.SubmissionTracker.submissionExceedsThreshold: If a submission is returned, it must be non-empty"
            }
            var submissionIndex = 0
            while submissionIndex < self.uniques.length {
                if self.counts[submissionIndex]! > threshold {
                    let submission = self.uniques[submissionIndex]
                    // exclude empty submissions, as these are ineligible for considering the DKG completed
                    if submission.isEmpty() {
                        submissionIndex = submissionIndex + 1
                        continue
                    }
                    // return the non-empty submission submitted by >threshold DKG participants
                    return submission
                }
                submissionIndex = submissionIndex + 1
            }
            return nil
        }

        // Returns the result submitted by the node with the given ID.
        // Returns nil if the node is not authorized or has not submitted for the current DKG.
        access(all) view fun getSubmissionByNodeID(_ nodeID: String): ResultSubmission? {
            if let submissionIndex = self.byNodeID[nodeID] {
                return self.uniques[submissionIndex]
            }
            return nil
        }

        // Returns all unique submissions for the current DKG instance.
        access(all) view fun getUniqueSubmissions(): [ResultSubmission] {
            return self.uniques
        }
    }

    /// The Participant resource is generated for each consensus node when they register.
    /// Each resource instance is good for all future potential epochs, but will
    /// only be valid if the node operator has been confirmed as a consensus node for the next epoch.
    access(all) resource Participant {

        /// The node ID of the participant
        access(all) let nodeID: String

        init(nodeID: String) {
            pre {
                FlowDKG.participantIsClaimed(nodeID) == nil:
                    "FlowDKG.Participant.init: Cannot create Participant resource for a node ID ("
                        .concat(nodeID)
                        .concat(") that has already been claimed")
            }
            self.nodeID = nodeID
            FlowDKG.nodeClaimed[nodeID] = true
        }

        /// Posts a whiteboard message to the contract
        access(all) fun postMessage(_ content: String) {
            pre {
                FlowDKG.participantIsRegistered(self.nodeID):
                    "FlowDKG.Participant.postMessage: Cannot post whiteboard message. Sender (node ID: "
                        .concat(self.nodeID)
                        .concat(") is not registered for the current DKG instance")
                content.length > 0:
                    "FlowDKG.Participant.postMessage: Cannot post empty message to the whiteboard"
                FlowDKG.dkgEnabled:
                    "FlowDKG.Participant.postMessage: Cannot post whiteboard message when DKG is disabled"
            }

            // create the message struct
            let message = Message(nodeID: self.nodeID, content: content)

            // add the message to the message record
            FlowDKG.whiteboardMessages.append(message)

            emit BroadcastMessage(nodeID: self.nodeID, content: content)

        }

        /// Sends the final key vector submission. 
        /// Can only be called by consensus nodes that are registered
        /// and can only be called once per consensus node per epoch
        access(all) fun sendFinalSubmission(_ submission: ResultSubmission) {
            pre {
                FlowDKG.dkgEnabled:
                    "FlowDKG.Participant.postMessage: Cannot send final submission when DKG is disabled"
            }
            FlowDKG.borrowSubmissionTracker().addSubmission(nodeID: self.nodeID, submission: submission)
        }
    }

    /// Interface that only contains operations that are part
    /// of the regular automated functioning of the epoch process
    /// These are accessed by the `FlowEpoch` contract through a capability
    access(all) resource interface EpochOperations {
        access(all) fun createParticipant(nodeID: String): @Participant
        access(all) fun startDKG(nodeIDs: [String])
        access(all) fun endDKG()
        access(all) fun forceEndDKG()
    }

    /// The Admin resource provides the ability to begin and end voting for an epoch
    access(all) resource Admin: EpochOperations {

        /// Sets the optional safe DKG success threshold
        /// Set the threshold to nil if it isn't needed
        access(all) fun setSafeSuccessThreshold(newThresholdPercentage: UFix64?) {
            pre {
                !FlowDKG.dkgEnabled:
                    "FlowDKG.Admin.setSafeSuccessThreshold: Cannot set the DKG success threshold while the DKG is enabled"
                newThresholdPercentage == nil ||  newThresholdPercentage! < 1.0:
                    "FlowDKG.Admin.setSafeSuccessThreshold: Invalid input. Safe threshold percentage must be in [0,1)"
            }

            FlowDKG.account.storage.load<UFix64>(from: /storage/flowDKGSafeThreshold)

            // If newThresholdPercentage is nil, we exit here. Since we loaded from
            // storage previously, this results in /storage/flowDKGSafeThreshold being empty
            if let percentage = newThresholdPercentage {
                FlowDKG.account.storage.save<UFix64>(percentage, to: /storage/flowDKGSafeThreshold)
            }
        }

        /// Creates a new Participant resource for a consensus node
        access(all) fun createParticipant(nodeID: String): @Participant {
            let participant <-create Participant(nodeID: nodeID)
            FlowDKG.nodeClaimed[nodeID] = true
            return <-participant
        }

        /// Resets all the fields for tracking the current DKG process
        /// and sets the given node IDs as registered
        access(all) fun startDKG(nodeIDs: [String]) {
            pre {
                FlowDKG.dkgEnabled == false:
                    "FlowDKG.Admin.startDKG: Cannot start the DKG when it is already running"
            }

            // Clear all per-instance DKG state
            FlowDKG.whiteboardMessages = []
            FlowDKG.borrowSubmissionTracker().reset(nodeIDs: nodeIDs)
            FlowDKG.uniqueFinalSubmissions = []     // deprecated and unused
            FlowDKG.uniqueFinalSubmissionCount = {} // deprecated and unused

            FlowDKG.dkgEnabled = true

            emit StartDKG()
        }

        /// Disables the DKG and closes the opportunity for messages and submissions
        /// until the next time the DKG is enabled
        access(all) fun endDKG() {
            pre { 
                FlowDKG.dkgEnabled == true:
                    "FlowDKG.Admin.endDKG: Cannot end the DKG when it is already disabled"
            }
            let dkgResult = FlowDKG.dkgCompleted()
            assert(
                dkgResult != nil,
                message: "FlowDKG.Admin.endDKG: Cannot end the DKG without a canonical final ResultSubmission"
            )

            FlowDKG.dkgEnabled = false

            emit EndDKG(finalSubmission: dkgResult)
        }

        /// Ends the DKG without checking if it is completed
        /// Should only be used if something goes wrong with the DKG,
        /// the protocol halts, or needs to be reset for some reason
        access(all) fun forceEndDKG() {
            FlowDKG.dkgEnabled = false

            emit EndDKG(finalSubmission: FlowDKG.dkgCompleted())
        }
    }

    /// Returns true if a node is registered as a consensus node for the proposed epoch
    access(all) view fun participantIsRegistered(_ nodeID: String): Bool {
        return FlowDKG.mustBorrowSubmissionTracker().authorized[nodeID] != nil
    }

    /// Returns true if a consensus node has claimed their Participant resource
    /// which is valid for all future epochs where the node is registered
    access(all) view fun participantIsClaimed(_ nodeID: String): Bool? {
        return FlowDKG.nodeClaimed[nodeID]
    }

    /// Gets an array of all the whiteboard messages
    /// that have been submitted by all nodes in the DKG
    access(all) view fun getWhiteBoardMessages(): [Message] {
        return self.whiteboardMessages
    }

    /// Returns whether this node has successfully submitted a final submission for this epoch.
    access(all) view fun nodeHasSubmitted(_ nodeID: String): Bool {
        return self.mustBorrowSubmissionTracker().byNodeID[nodeID] != nil
    }

    /// Gets the specific final submission for a node ID
    /// If the node hasn't submitted or registered, this returns `nil`
    access(all) view fun getNodeFinalSubmission(_ nodeID: String): ResultSubmission? {
        return self.mustBorrowSubmissionTracker().getSubmissionByNodeID(nodeID)
    }

    /// Get the list of all the consensus node IDs participating
    access(all) view fun getConsensusNodeIDs(): [String] {
        return *self.mustBorrowSubmissionTracker().authorized.keys
    }

    /// Get the array of all the unique final submissions
    access(all) view fun getFinalSubmissions(): [ResultSubmission] {
        return self.mustBorrowSubmissionTracker().getUniqueSubmissions()
    }

    /// Get the count of the final submissions array
    access(all) view fun getFinalSubmissionCount(): {Int: UInt64} {
        return *self.mustBorrowSubmissionTracker().counts
    }

    /// Gets the native threshold that the submission count needs to exceed to be considered complete [t=floor((n-1)/2)]
    /// This function returns the NON-INCLUSIVE lower bound of honest participants.
    /// For the DKG to succeed, the number of honest participants must EXCEED this threshold value.
    /// 
    /// Example:
    /// We have 10 DKG nodes (n=10)
    /// The threshold value is t=floor(10-1)/2) (t=4)
    /// There must be AT LEAST 5 honest nodes for the DKG to succeed
    /// The function must match the threshold computation on the protocol side: https://github.com/onflow/flow-go/blob/master/module/signature/threshold.go#L7
    access(all) view fun getNativeSuccessThreshold(): UInt64 {
        let n = self.getConsensusNodeIDs().length
        // avoid initializing the threshold to 0 when n=2
        if n == 2 {
            return 1
        }
        return UInt64((n-1)/2)
    }

    /// Gets the safe threshold that the submission count needs to exceed to be considered complete.
    /// (always greater than or equal to the native success threshold)
    /// 
    /// This function returns the NON-INCLUSIVE lower bound of honest participants. If this function 
    /// returns threshold t, there must be AT LEAST t+1 honest nodes for the DKG to succeed.
    access(all) view fun getSafeSuccessThreshold(): UInt64 {
        var threshold = self.getNativeSuccessThreshold()

        // Get the safety rate percentage
        if let safetyRate = self.getSafeThresholdPercentage() {

            let safeThreshold = UInt64(safetyRate * UFix64(self.getConsensusNodeIDs().length))

            if safeThreshold > threshold {
                threshold = safeThreshold
            }
        }

        return threshold
    }

    /// Gets the safe threshold percentage. This value must be either nil (semantically: 0) or in [0, 1.0)
    /// This safe threshold is used to artificially increase the DKG participation requirements to 
    /// ensure a lower-bound number of Random Beacon Committee members (beyond the bare minimum required
    /// by the DKG protocol).
    access(all) view fun getSafeThresholdPercentage(): UFix64? {
        let safetyRate = self.account.storage.copy<UFix64>(from: /storage/flowDKGSafeThreshold)
        return safetyRate
    }

    // Borrows the singleton SubmissionTracker from storage, creating it if none exists.
    access(contract) fun borrowSubmissionTracker(): &FlowDKG.SubmissionTracker {
        // The singleton SubmissionTracker already exists in storage - return a reference to it.
        if let tracker = self.account.storage.borrow<&SubmissionTracker>(from: /storage/flowDKGFinalSubmissionTracker) {
            return tracker
        }
        // The singleton SubmissionTracker has not been created yet - create it and return a reference.
        // This codepath should be executed at most once per FlowDKG instance and only if it was upgraded from an older version.
        self.account.storage.save(SubmissionTracker(), to: /storage/flowDKGFinalSubmissionTracker)
        return self.mustBorrowSubmissionTracker()
    }

    // Borrows the singleton SubmissionTracker from storage; panics if none exists.
    access(contract) view fun mustBorrowSubmissionTracker(): &FlowDKG.SubmissionTracker {
        return self.account.storage.borrow<&SubmissionTracker>(from: /storage/flowDKGFinalSubmissionTracker) ??
            panic("FlowDKG.mustBorrowSubmissionTracker: Critical invariant violated! No SubmissionTracker instance stored at /storage/flowDKGFinalSubmissionTracker")
    }

    /// Returns the final set of keys if any one set of keys has strictly more than (nodes-1)/2 submissions
    /// Returns nil if not found (incomplete)
    access(all) fun dkgCompleted(): ResultSubmission? {
        if !self.dkgEnabled { return nil }

        let threshold = self.getSafeSuccessThreshold()
        return self.borrowSubmissionTracker().submissionExceedsThreshold(threshold)
    }

    init() {
        self.submissionKeyLength = 192 // 96 bytes, hex-encoded

        self.AdminStoragePath = /storage/flowEpochsDKGAdmin
        self.ParticipantStoragePath = /storage/flowEpochsDKGParticipant
        self.ParticipantPublicPath = /public/flowEpochsDKGParticipant

        self.dkgEnabled = false

        self.finalSubmissionByNodeID = {}    // deprecated
        self.uniqueFinalSubmissionCount = {} // deprecated
        self.uniqueFinalSubmissions = []     // deprecated
        
        self.nodeClaimed = {}
        self.whiteboardMessages = []

        self.account.storage.save(<-create Admin(), to: self.AdminStoragePath)
        self.account.storage.save(SubmissionTracker(), to: /storage/flowDKGFinalSubmissionTracker)
    }
}
 
