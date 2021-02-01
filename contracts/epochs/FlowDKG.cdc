
pub contract FlowDKG {

    pub event StartDKG()
    pub event EndDKG(finalSubmission: [String]?)

    pub event BroadcastMessage(nodeID: String, content: String)
    pub event FinalSubmission(nodeID: String, submission: [String])

    // ================================================================================
    // CONTRACT VARIABLES
    // ================================================================================

    /// The length of keys that have to be submitted as a final submission
    pub let submissionKeyLength: Int

    // indicates if the DKG is enabled or not
    pub var dkgEnabled: Bool

    // Indicates if a Participant resource has already been claimed by a node ID
    // from the identity table contract
    // Node IDs have to claim a participant once
    // one node will use the same specific ID and Participant resource for all time
    // `nil` or false means that there is no voting capability for the node ID
    // true means that the participant capability has been claimed by the node
    access(account) var nodeClaimed: {String: Bool}

    /// Record of whiteboard messages
    access(account) var whiteboardMessages: [Message]

    // Tracks if a node has submitted their final submission for the epoch
    // reset every epoch
    access(account) var nodeFinalSubmission: {String: [String]}

    /// Array of unique final submissions from nodes
    /// if a final submission is sent that matches one that already has been submitted
    /// this array will not change at all
    access(account) var uniqueFinalSubmissions: [[String]]

    /// Tracks how many submissions have been sent
    /// for each unique final submission
    access(account) var uniqueFinalSubmissionCount: {Int: UInt64}

    // ================================================================================
    // CONTRACT CONSTANTS
    // ================================================================================

    // Canonical paths for admin and participant resources
    pub let AdminStoragePath: StoragePath
    pub let ParticipantStoragePath: StoragePath
    pub let ParticipantPublicPath: PublicPath

    /// Struct to represent a single whiteboard message
    pub struct Message {

        pub let nodeID: String

        pub let content: String

        init(nodeID: String, content: String) {
            self.nodeID = nodeID
            self.content = content
        }
    }

    // The Participant resource is generated for each consensus node when they register.
    // Each resource instance is good for all future potential epochs, but will
    // only be valid if the node operator has been confirmed as a consensus node for the next epoch.
    pub resource Participant {

        pub let nodeID: String

        // Posts a whiteboard message to the contract
        pub fun postMessage(_ content: String) {
            pre {
                FlowDKG.participantIsRegistered(self.nodeID): "Cannot send whiteboard message if not registered for the current epoch"
            }

            // create the message struct
            let message = Message(nodeID: self.nodeID, content: content)

            // add the message to the message record
            FlowDKG.whiteboardMessages.append(message)

            emit BroadcastMessage(nodeID: self.nodeID, content: content)

        }

        /// Sends the final key vector submission. 
        /// Can only be called by consensus nodes that are registered.
        pub fun sendFinalSubmission(_ submission: [String]) {
            pre {
                FlowDKG.participantIsRegistered(self.nodeID): "Cannot send final submission if not registered for the current epoch"
                FlowDKG.nodeHasSubmitted(self.nodeID)!.length == 0: "Cannot submit a final submission twice"
                submission.length == FlowDKG.nodeFinalSubmission.keys.length + 1: "Submission must have number of elements equal to the number of nodes participating in the DKG"
            }

            var finalSubmissionIndex = 0

            // iterate through all the existing unique submissions
            // If this participant's submission matches one of the existing ones,
            // add to the counter for that submission
            // Otherwise, track the new submission and set its counter to 1
            for existingSubmission in FlowDKG.uniqueFinalSubmissions {

                // If the submissions are equal,
                // update the counter for this submission and emit the event
                if FlowDKG.submissionsEqual(existingSubmission, submission) {
                    FlowDKG.uniqueFinalSubmissionCount[finalSubmissionIndex] = FlowDKG.uniqueFinalSubmissionCount[finalSubmissionIndex]! + 1 as UInt64
                    emit FinalSubmission(nodeID: self.nodeID, submission: submission)
                    break
                }

                // update the index counter
                finalSubmissionIndex = finalSubmissionIndex + 1

                // If no matches were found, add this submission as a new unique one
                // and emit an event
                if finalSubmissionIndex == FlowDKG.uniqueFinalSubmissions.length {
                    FlowDKG.uniqueFinalSubmissionCount[finalSubmissionIndex] = 0
                    FlowDKG.uniqueFinalSubmissions.append(submission)
                    emit FinalSubmission(nodeID: self.nodeID, submission: submission)
                }
            }
        }

        init(nodeID: String) {
            pre {
                FlowDKG.participantIsRegistered(nodeID): "Cannot create a Participant for a node ID that hasn't been registered"
                !FlowDKG.participantIsClaimed(nodeID)!: "Cannot create a Participant resource for a node ID that has already been claimed"
            }
            self.nodeID = nodeID
            FlowDKG.nodeClaimed[nodeID] = true
        }

        destroy () {
            FlowDKG.nodeClaimed[self.nodeID] = false
        }

    }

    // The Admin resource provides the ability to begin and end voting for an epoch
    pub resource Admin {

        /// Creates a new Participant resource for a consensus node
        pub fun createParticipant(_ nodeID: String): @Participant {
            let participant <-create Participant(nodeID: nodeID)
            FlowDKG.nodeClaimed[nodeID] = true
            return <-participant
        }

        /// Resets all the fields for tracking the current DKG process
        /// and sets the given node IDs as registered
        pub fun startDKG(nodeIDs: [String]) {
            FlowDKG.dkgEnabled = true

            FlowDKG.nodeFinalSubmission = {}
            for id in nodeIDs {
                FlowDKG.nodeFinalSubmission[id] = []
            }

            FlowDKG.whiteboardMessages = []

            FlowDKG.uniqueFinalSubmissions = []

            FlowDKG.uniqueFinalSubmissionCount = {}

            emit StartDKG()
        }

        pub fun endDKG() {
            FlowDKG.dkgEnabled = false

            emit EndDKG(finalSubmission: FlowDKG.dkgCompleted())
        }
    }

    access(account) fun submissionsEqual(_ existingSubmission: [String], _ submission: [String]): Bool {

        // If the submission length is different than the one being compared to, it is not equal
        if submission.length != existingSubmission.length {
            return false
        }

        var index = 0

        // Check each key in the submiission to make sure that it matches
        // the existing one
        for key in submission {
            // If a key length is incorrect, it is an invalid submission
            if key.length != FlowDKG.submissionKeyLength {
                panic("Submission key length is not correct!")
            }

            // if a key is different, stop checking this submission
            // and move on to the next one
            if key != existingSubmission[index] {
                return false
            }

            index = index + 1
        }

        return true

    }

    pub fun participantIsRegistered(_ nodeID: String): Bool {
        return FlowDKG.nodeFinalSubmission[nodeID] != nil
    }

    pub fun participantIsClaimed(_ nodeID: String): Bool? {
        return FlowDKG.nodeClaimed[nodeID]
    }

    // specify last X messages in the transaction
    pub fun getWhiteBoardMessages(): [Message] {
        return self.whiteboardMessages
    }

    /// Returns whether this node has successfully submitted a final submission for this epoch.
    /// Returns nil if the node is not a participant
    /// Returns empty array if the node is a participant or hasn't submitted
    /// Returns a submission array if the node has submitted
    pub fun nodeHasSubmitted(_ nodeID: String): [String]? {
        return self.nodeFinalSubmission[nodeID]
    }

    /// Get the list of all the consensus node IDs participating
    pub fun getConsensusNodeIDs(): [String] {
        return self.nodeFinalSubmission.keys
    }

    /// Get the array of all the unique final submissions
    pub fun getFinalSubmissions(): [[String]] {
        return self.uniqueFinalSubmissions
    }

    /// Returns the final set of keys if any one set of keys has more than 50% submissions
    /// Returns nil if not found (incomplete)
    pub fun dkgCompleted(): [String]? {

        var index = 0

        for submission in self.uniqueFinalSubmissions {
            if self.uniqueFinalSubmissionCount[index]! > UInt64(self.nodeFinalSubmission.keys.length/2) {
                return submission
            }
            index = index + 1
        }

        return nil
    }

    init() {
        self.submissionKeyLength = 128

        self.AdminStoragePath = /storage/flowEpochsDKGAdmin
        self.ParticipantStoragePath = /storage/flowEpochsDKGParticipant
        self.ParticipantPublicPath = /public/flowEpochsDKGParticipant

        self.dkgEnabled = false

        self.nodeFinalSubmission = {}
        self.uniqueFinalSubmissionCount = {}
        self.uniqueFinalSubmissions = []
        
        self.nodeClaimed = {}
        self.whiteboardMessages = []

        self.account.save(<-create Admin(), to: self.AdminStoragePath)
    }
}
 