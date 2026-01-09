# Switchboard On-Demand Oracle Rule

This package integrates [Switchboard](https://switchboard.xyz/) on-demand price feeds into the Scallop xOracle system.

## Structure

- `sources/` - Oracle rule implementation
- `typescript/` - TypeScript utilities for deployment and interaction

## Prerequisites

1. Ensure `Move.${networkType}.toml` has correct addresses for Switchboard dependencies
2. Prepare the `switchboard-oracle.${networkType}.json` file with feed configurations

## Configuration Files

- `switchboard-oracle.mainnet.json` - Mainnet feed configurations
- `switchboard-oracle.testnet.json` - Testnet feed configurations
