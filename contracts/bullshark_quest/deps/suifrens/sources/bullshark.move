// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Defines the Bullshark type analogous to the Capy type defined in the `capy`
/// module.
module suifrens::bullshark {
    use suifrens::suifrens::AdminCap;

    /// The Bullshark type.
    struct Bullshark has drop {}

    /// Create a witness for the Bullshark.
    public fun bullshark(_: &AdminCap): Bullshark {
        Bullshark {}
    }
}
