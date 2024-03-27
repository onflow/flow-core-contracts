import FlowIDTableStaking from "FlowIDTableStaking"

// This script returns the list of non-operational nodes

access(all) fun main(): [String] {
    return FlowIDTableStaking.getNonOperationalNodesList().keys
}