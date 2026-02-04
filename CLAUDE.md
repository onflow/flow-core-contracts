# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains the core smart contracts for the Flow blockchain, written in Cadence. The `master` branch contains the Cadence 1.0 version (not yet deployed to mainnet/testnet - see `cadence-0.42` branch for deployed versions).

## Build and Test Commands

```bash
# Run all tests (Go tests + Cadence tests)
make test

# Run only Cadence tests
flow test --cover --covercode="contracts" tests/*_test.cdc

# Run a single Cadence test file
flow test tests/dkg_test.cdc

# Run Go tests only
make -C lib/go test

# Generate Go template code (required before running Go tests)
make generate

# Run CI checks (includes go mod tidy verification)
make ci
```

## Architecture

### Contract Dependency Hierarchy

The contracts have specific deployment order dependencies:

1. **FlowToken** (`contracts/FlowToken.cdc`) - Network token, foundational dependency
2. **FlowFees** (`contracts/FlowFees.cdc`) - Transaction and account fees
3. **FlowStorageFees** (`contracts/FlowStorageFees.cdc`) - Storage cost management
4. **FlowServiceAccount** (`contracts/FlowServiceAccount.cdc`) - Account creation and flow token initialization
5. **FlowIDTableStaking** (`contracts/FlowIDTableStaking.cdc`) - Node staking and identity management
6. **Epoch contracts** (`contracts/epochs/`):
   - `FlowClusterQC.cdc` - Quorum Certificate for collector clusters
   - `FlowDKG.cdc` - Distributed Key Generation for consensus nodes
   - `FlowEpoch.cdc` - Epoch lifecycle management (depends on FlowIDTableStaking, FlowClusterQC, FlowDKG)
7. **LockedTokens** (`contracts/LockedTokens.cdc`) - Two-year token lockup for initial sale
8. **FlowStakingCollection** (`contracts/FlowStakingCollection.cdc`) - Unified staking interface for managing multiple staking objects

### Staking System

The staking system has three layers:
- **FlowIDTableStaking**: Core staking logic for node operators and delegators
- **LockedTokens**: Manages locked tokens from initial sale, integrates with staking
- **FlowStakingCollection**: Modern unified interface that supports multiple nodes/delegators per account using both locked and unlocked tokens

### Transaction Templates

- Cadence transactions in `transactions/` directory organized by contract
- Go template generators in `lib/go/templates/` for programmatic access
- Manifest files (`manifest.mainnet.json`, `manifest.testnet.json`) generated via `make generate`

### Testing

Two test suites:
1. **Cadence tests** (`tests/*.cdc`) - Use Flow's native test framework with `Test` and `BlockchainHelpers` imports
2. **Go tests** (`lib/go/test/*_test.go`) - Integration tests using Go SDK

Cadence tests deploy contracts using `Test.deployContract()` and account `0x0000000000000007` as the default admin.

## Network Contract Addresses

Key addresses vary by network (see `flow.json` for full mapping):
- **Emulator**: Service account at `0xf8d6e0586b0a20c7`
- **Testnet**: Staking contracts at `0x9eca2b38b18b5dfe`, FlowToken at `0x7e60df042a9c0868`
- **Mainnet**: Staking contracts at `0x8624b52f9ddcd04a`, FlowToken at `0x1654653399040a61`
