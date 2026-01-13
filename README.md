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

## Indix.sol - Pre-Game Asset And Rental Engine

Indix.sol is the core per-game contract deployed as a minimal proxy clone by IndixFactory.
Each instance represents one game, fully isolated in state, assets, and economy.

It manages:

-   Game access keys
-   ERC-1155 in-game assets (skins)
-   Primary sales
-   Time-based rentals
-   Transfer restrictions during active rentals

### Core Responsibilities

Game Identity

-   GAME_ID uniquely identifies the game instance
-   GAME_DEVELOPER is the publisher with elevated permissions
-   gameKeyPrice defines the entry cost for players

**Game Keys (Token ID = 1)**

Token ID 1 is reserved for game access keys

-   Keys are minted on purchase
-   Supply is capped and controlled by the developer
    > purchaseGameKey()
-   Requires exact ETH payment
-   Mints 1 key per call
-   Enforces global supply limits

**In-Game Skins (ERC-1155)**
All skins use token IDs >= 2.
**Skin Creation**

> createSkin(name, supply, price, uri)

-   Only callable by the game developer
-   Mints a new ERC-1155 token type
-   Associates metadata and primary sale price
-   Initial supply is owned by the developer

Each skin’s economic metadata is stored per owner, enabling:

-   Secondary sales
-   Rentals
-   Future extensions (e.g. lending, upgrades)

**Skin Purchase**

> purchaseSkinFor(skinId, recipient)

-   Allows purchasing a skin on behalf of another address
-   Transfers directly from developer inventory
-   Enforces stock availability via balanceOf
-   Applies a platform fee (1%)
-   Sends proceeds to the developer

**Rental System (Time-Based Usage Rights)**
The rental system is designed to:

-   Avoid token custody transfers
-   Avoid loops
-   Avoid per-token tracking
-   Remain gas-efficient and deterministic

Rent Listings
Owners may list a portion of their balance for rent:

> listForRent(skinId, quantity, pricePerUnit, duration)

Each listing specifies:

-   Rental price per unit
-   Fixed rental duration
-   Number of units available
    Listings can be removed at any time using unlistFromRent.

**Renting a Skin**

> rentSkin(skinId, owner, amount)

-   Renter pays upfront for usage rights
-   No ERC-1155 transfer occurs
-   Rental state is tracked via ActiveRent
-   Rental expires automatically via timestamp

Fees are split between:

-   Platform
-   Game developer
-   Asset owner

**Active Rental State**

```bash
struct ActiveRent {
    address owner;
    uint256 amount;
    uint256 expiresAt;
}
```

-   Tracks how many units are locked
-   No per-unit tracking → ERC-1155 compatible
-   Designed for fungible skins
    Expired rentals are ignored automatically and can optionally be cleared by users.

**Transfer Restrictions (Rental-Aware)**
The contract overrides safeTransferFrom to enforce rental locks:

> transferable = balance - locked

-   Locked amount is derived lazily
-   No loops
-   No forced cleanup
-   Expired rentals do not block transfers

This ensures:

-   Owners cannot transfer rented units
-   Non-rented units remain transferable
-   Gas costs remain minimal

### Design Philosophy

**Lazy Cleanup**

-   Expired rentals do not require immediate storage cleanup
-   State is ignored when expired
-   Users may clear expired rentals voluntarily

**No Token Escrow**

-   Tokens never leave the owner’s wallet during rent
-   Usage rights are enforced at the contract level
-   Reduces attack surface and complexity

**ERC-1155 First**

-   All logic is designed around fungible balances
-   No per-token iteration
-   Compatible with large inventories

**Access Control & Safety**

-   Upgradeable-safe initialization
-   Per-game pausing
-   Strict developer permissions
-   No operator approvals allowed
-   No batch transfers (intentionally disabled)

**Upgrade Strategy**

-   Each game clone is immutable
-   New features are introduced via new blueprint deployments
-   Existing games remain untouched
-   Avoids proxy upgrade risks while maintaining extensibility
