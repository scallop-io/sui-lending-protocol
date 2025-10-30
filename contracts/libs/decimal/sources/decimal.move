module decimal::decimal;

use std::fixed_point32::{Self, FixedPoint32};

const WAD: u256 = 1000000000000000000; // 10^18

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
    if (b.eq(from(2)) && e == 32) return from(4_294_967_296);
    if (b.eq(from(10)) && e == 9) return from(1_000_000_000);
    if (b.eq(from(10)) && e == 8) return from(100_000_000);
    if (b.eq(from(10)) && e == 7) return from(10_000_000);
    if (b.eq(from(10)) && e == 6) return from(1_000_000);
    
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

public fun from_fixed_point32(fp: FixedPoint32): Decimal {
    div(
        from(fp.get_raw_value()), 
        pow(from(2), 32)
    )
}

#[test]
fun pow_test() {
    let x = pow(from(2), 16 + 16); // 2^32
    assert!(eq(x, from(4_294_967_296)), 0);

    let x = pow(from(2), 30); // 2^30
    assert!(eq(x, from(1_073_741_824)), 0);

    let x = pow(from(10), 9); // 10^9
    assert!(eq(x, from(1_000_000_000)), 0);

    let x = pow(from(10), 8); // 10^8
    assert!(eq(x, from(100_000_000)), 0);

    let x = pow(from(10), 7); // 10^7
    assert!(eq(x, from(10_000_000)), 0);

    let x = pow(from(10), 6); // 10^6
    assert!(eq(x, from(1_000_000)), 0);

    let x = pow(from(10), 5); // 10^5
    assert!(eq(x, from(100_000)), 0);

    let x = pow(from(10), 0); // 10^0
    assert!(eq(x, from(1)), 0);    
}

#[test]
fun from_fixed_point32_test() {
    let a = fixed_point32::create_from_rational(1, 1);
    let b = from_fixed_point32(a);

    assert!(eq(b, from(1)));

    let a = fixed_point32::create_from_rational(1, 2);
    let b = from_fixed_point32(a);

    assert!(eq(b, from_percent(50)));

    let a = fixed_point32::create_from_rational(1, 4);
    let b = from_fixed_point32(a);

    assert!(eq(b, from_percent(25)));
}