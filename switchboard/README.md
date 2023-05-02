<div align="center">
  <a href="#">
    <img src="https://github.com/switchboard-xyz/sbv2-core/raw/main/website/static/img/icons/switchboard/avatar.png" />
  </a>

  <h1>switchboard-move</h1>

  <p>A Move module to interact with Switchboard V2 on Sui.</p>

  <p>
    <a href="https://discord.gg/switchboardxyz">
      <img alt="Discord" src="https://img.shields.io/discord/841525135311634443?color=blueviolet&logo=discord&logoColor=white" />
    </a>
    <a href="https://twitter.com/switchboardxyz">
      <img alt="Twitter" src="https://img.shields.io/twitter/follow/switchboardxyz?label=Follow+Switchboard" />
    </a>
  </p>

  <h4>
    <strong>Sbv2 Sui SDK: </strong><a href="https://github.com/switchboard-xyz/sbv2-sui">github.com/switchboard-xyz/sbv2-sui</a>
  </h4>
</div>

## Build

```bash
sui move compile
```

## Install

Add the following to your `Move.toml`.

```toml
[package]
name = "Package"
version = "0.0.1"

[dependencies]
MoveStdlib = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/deps/move-stdlib", rev = "devnet" }
Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework", rev = "devnet" }
switchboard = { git = "https://github.com/switchboard-xyz/sbv2-sui.git", subdir = "move/switchboard/", rev = "main"  }

[addresses]
package = "0x0"
std = "0x1"
sui =  "0x2"
switchboard =  "0x8c8b750023fbd573955c431fb4395e7e396aaca3"
```

## Usage

### Reading Feeds

```move
use switchboard::aggregator;
use switchboard::math;

// store latest value
struct AggregatorInfo has store, key {
    id: UID,
    aggregator_addr: address,
    latest_result: u128,
    latest_result_scaling_factor: u8,
    round_id: u128,
    latest_timestamp: u64,
}

// get latest value
public entry fun save_aggregator_info(
    feed: &Aggregator,
    ctx: &mut TxContext
) {
    let (latest_result, latest_timestamp, round_id) = aggregator::latest_value(feed);

    // get latest value
    let (value, scaling_factor, _neg) = math::unpack(latest_result);
    transfer::transfer(
        AggregatorInfo {
            id: object::new(ctx),
            latest_result: value,
            latest_result_scaling_factor: scaling_factor,
            aggregator_addr: aggregator::aggregator_address(feed),
            latest_timestamp,
            round_id,
        },
        tx_context::sender(ctx)
    );
}
```
