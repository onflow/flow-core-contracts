# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository contains the core smart contracts for the Flow blockchain, written in Cadence.

## Build and Test Commands

```bash
# Run all tests (Go tests + Cadence tests)
make test

# Run only Cadence tests
flow test --cover --covercode="contracts" tests/*_test.cdc

# Run a single Cadence test file
flow test tests/dkg_test.cdc

# Run a specific Cadence test case
flow test tests/dkg_test.cdc --name "testResultSubmissionInit_InvalidGroupKeyLength"

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

New tests should be written in Cadence where possible.

Before committing and pushing, all tests in `make test` and `make ci` should pass.

## Network Contract Addresses

Key addresses vary by network (see `flow.json` for full mapping):
- **Emulator**: Service account at `0xf8d6e0586b0a20c7`
- **Testnet**: Staking contracts at `0x9eca2b38b18b5dfe`, FlowToken at `0x7e60df042a9c0868`
- **Mainnet**: Staking contracts at `0x8624b52f9ddcd04a`, FlowToken at `0x1654653399040a61`


## Workflow Orchestration

### 1. Planning
- If something goes sideways, STOP and re-plan immediately - don't keep pushing
- Write detailed specs upfront to reduce ambiguity

### 2. Subagent Strategy to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

### 3. Self-Improvement Loop
- After ANY correction from the user: update 'tasks/lessons.md' with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### 4. Verification Before Done
- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

### 5. Demand Elegance (Balanced)
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes - don't over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing
- When fixing a big, point at logs, errors, failing tests -> then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

## Task Management
1. **Plan First**: Write plan to 'tasks/todo.md' with checkable items
2. **Verify Plan**: Check in before starting implementation
3. **Track Progress**: Mark items complete as you go
4. **Explain Changes**: High-level summary at each step
5. **Document Results**: Add review to 'tasks/todo.md'
6. **Capture Lessons**: Update 'tasks/lessons.md' after corrections

## Core Principles
- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.

