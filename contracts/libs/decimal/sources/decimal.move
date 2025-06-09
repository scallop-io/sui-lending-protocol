module decimal::decimal {
    const WAD: u256 = 1000000000000000000; // 10^18
    const U64_MAX: u256 = 18446744073709551615;

    public struct Decimal has copy, drop, store {
        value: u256,
    }

    public fun from(v: u64): Decimal {
        Decimal {
            value: (v as u256) * WAD,
        }
    }

    public fun from_u128(v: u128): Decimal {
        Decimal {
            value: (v as u256) * WAD
        }
    }

    public fun from_percent(v: u8): Decimal {
        Decimal {
            value: (v as u256) * WAD / 100,
        }
    }

    public fun from_percent_u64(v: u64): Decimal {
        Decimal {
            value: (v as u256) * WAD / 100,
        }
    }

    public fun from_bps(v: u64): Decimal {
        Decimal {
            value: (v as u256) * WAD / 10_000,
        }
    }

    public fun from_scaled_val(v: u256): Decimal {
        Decimal {
            value: v,
        }
    }

    public fun to_scaled_val(v: Decimal): u256 {
        v.value
    }

    public fun add(a: Decimal, b: Decimal): Decimal {
        Decimal {
            value: a.value + b.value,
        }
    }

    public fun sub(a: Decimal, b: Decimal): Decimal {
        Decimal {
            value: a.value - b.value,
        }
    }

    public fun saturating_sub(a: Decimal, b: Decimal): Decimal {
        if (a.value < b.value) {
            Decimal { value: 0 }
        } else {
            Decimal { value: a.value - b.value }
        }
    }

    public fun mul(a: Decimal, b: Decimal): Decimal {
        Decimal {
            value: (a.value * b.value) / WAD,
        }
    }

    public fun div(a: Decimal, b: Decimal): Decimal {
        Decimal {
            value: (a.value * WAD) / b.value,
        }
    }

    public fun pow(b: Decimal, mut e: u64): Decimal {
        let mut cur_base = b;
        let mut result = from(1);

        while (e > 0) {
            if (e % 2 == 1) {
                result = mul(result, cur_base);
            };
            cur_base = mul(cur_base, cur_base);
            e = e / 2;
        };

        result
    }

    public fun floor(a: Decimal): u64 {
        ((a.value / WAD) as u64)
    }

    public fun saturating_floor(a: Decimal): u64 {
        if (a.value > U64_MAX * WAD) {
            (U64_MAX as u64)
        } else {
            floor(a)
        }
    }

    public fun ceil(a: Decimal): u64 {
        (((a.value + WAD - 1) / WAD) as u64)
    }

    public fun eq(a: Decimal, b: Decimal): bool {
        a.value == b.value
    }

    public fun ge(a: Decimal, b: Decimal): bool {
        a.value >= b.value
    }

    public fun gt(a: Decimal, b: Decimal): bool {
        a.value > b.value
    }

    public fun le(a: Decimal, b: Decimal): bool {
        a.value <= b.value
    }

    public fun lt(a: Decimal, b: Decimal): bool {
        a.value < b.value
    }

    public fun min(a: Decimal, b: Decimal): Decimal {
        if (a.value < b.value) {
            a
        } else {
            b
        }
    }

    public fun max(a: Decimal, b: Decimal): Decimal {
        if (a.value > b.value) {
            a
        } else {
            b
        }
    }
}