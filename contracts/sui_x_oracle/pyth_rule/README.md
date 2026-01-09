# Pyth Oracle Rule

This package integrates [Pyth Network](https://pyth.network/) price feeds into the Scallop xOracle system.

## Structure

- `sources/rule.move` - Main oracle rule implementation
- `sources/pyth_adaptor.move` - Pyth price feed adaptor
- `sources/pyth_registry.move` - Registry for Pyth price feed IDs
- `vendors/` - Pyth and Wormhole dependencies

## Prerequisites

1. Prepare the `pyth-oracle.${networkType}.json` file with the correct price feed IDs
2. Ensure `Move.${networkType}.toml` has correct addresses for `vendors/pyth` and `vendors/wormhole`

## Configuration Files

- `pyth-oracle.mainnet.json` - Mainnet price feed configurations
- `pyth-oracle.testnet.json` - Testnet price feed configurations
