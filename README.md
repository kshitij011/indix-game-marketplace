# Index Game Marketplace

-   A decentralized game publishing and asset marketplace where game developers deploy isolated game instances, and players interact with in-game items in a trust-minimized way.

-   The platform uses a factory + minimal proxy (EIP-1167 clones) architecture to enable gas-efficient deployment of per-game smart contracts.

## Architecture Overview

```bash
IndixFactory
├── Deploys minimal proxy clones (EIP-1167)
├── Manages publisher staking & game lifecycle
└── Coordinates rewards and game access

Indix (Blueprint Implementation)
├── Per-game isolated state
├── In-game assets (skins, keys, etc.)
├── Pause / unpause controls
└── Purchase logic
```

Each published game is deployed as an independent clone, ensuring:

-   State isolation between games
-   Low deployment gas costs
-   No shared risk across publishers

## How to run

1. Deploy Indix contract first, copy it's address (required as blueprint for IndixFactory).

2. Pass copied address to IndixFactory's constructor while deploying it.

3. Call registerGame function to deploy clones of the Indix contract.

## Indix Factory

The IndixFactory contract is responsible for deploying game instances, enforcing publisher staking, and coordinating reward logic.

> lockFunds()

Publishers must stake 0.1 ETH before publishing games.

-   Required to deploy games
-   Unlocks interaction for previously paused games
-   Funds act as a commitment mechanism
    If the stake is withdrawn, all games owned by the publisher are paused.

> registerGame(string gameName, uint256 gameKeyPrice)

Deploys a new game instance as a minimal proxy clone.

-   Deploys a clone of the Indix blueprint
-   Initializes the game with:

*   Game ID
*   Publisher address
*   Game key price

-   Registers ownership and metadata in the factory
    Each publisher can deploy up to 100 games.

> withdrawStake()

Withdraws the publisher’s locked stake.

-   Pauses all games owned by the publisher
-   Prevents further interaction until funds are re-locked
-   Uses nonReentrant protection

> openCrate():

Entry point for reward logic.

-   Placeholder for future Chainlink VRF integration
-   Currently disabled and marked as “coming soon”

> claimReward(uint256 gameId, uint256 skinId)
> Allows eligible players to claim a reward from a game.

-   Validates:

*   Game existence
*   Reward eligibility
*   Skin availability and price constraints

-   Purchases the reward skin on behalf of the player
-   Resets reward eligibility after claim

### Security & Design Considerations

-   Minimal Proxies (EIP-1167)

*   Efficient game deployment with O(1) gas overhead.

-   State Isolation

*   Each game operates independently with no shared storage.

-   Reentrancy Protection

*   Applied to all ETH-handling functions.

-   Pausable Game Instances

*   Publisher stake directly controls game availability.

### Upgrade Strategy

The system follows a versioned blueprint model:

-   Existing game clones are immutable
-   New features (e.g. VRF) are introduced by deploying a new Indix implementation
-   Future clones can point to the upgraded blueprint without affecting existing games.This avoids proxy complexity while preserving long-term extensibility.
