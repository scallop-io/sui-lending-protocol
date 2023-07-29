// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// For each SuiFren we should create a separate module like suifren::capy so that
/// we can have the type + we keep the door open for witness extensions
/// and create a capy(): Capy function.
module suifrens::capy {
    use suifrens::suifrens::AdminCap;

    struct Capy has drop {}

    /// Create a the `Capy` Witness in case there's a need to authorize
    /// a third party application.
    public fun capy(_: &AdminCap): Capy {
        Capy {}
    }
}
