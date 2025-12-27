# Switchboard Oracle Rule

This package integrates [Switchboard](https://switchboard.xyz/) standard price feeds into the Scallop xOracle system.

## Structure

- `sources/` - Oracle rule implementation
- `vendors/switchboard_std` - Switchboard standard library dependency

## Prerequisites

1. Ensure `Move.${networkType}.toml` has correct addresses for `vendors/switchboard_std`
