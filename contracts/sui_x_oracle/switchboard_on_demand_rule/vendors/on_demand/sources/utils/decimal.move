module switchboard::decimal;

use std::u128;

const DECIMALS: u8 = 18;


public struct Decimal has copy, drop, store { value: u128, neg: bool }

public fun zero(): Decimal {
    Decimal {
        value: 0,
        neg: false
    }
}

public fun new(value: u128, neg: bool): Decimal {
    Decimal { value, neg }
}

public fun unpack(num: Decimal): (u128, bool) {
    let Decimal { value, neg } = num;
    (value, neg)
}

public fun value(num: &Decimal): u128 {
    num.value
}

public fun dec(_: &Decimal): u8 {
    DECIMALS
}

public fun neg(num: &Decimal): bool {
    num.neg
}

public fun max_value(): Decimal {
    Decimal {
        value: u128::max_value!(),
        neg: false
    }
}

public fun equals(a: &Decimal, b: &Decimal): bool {
    a.value == b.value && a.neg == b.neg
}

public fun gt(a: &Decimal, b: &Decimal): bool {
    if (a.neg && b.neg) {
        return a.value < b.value
    } else if (a.neg) {
        return false
    } else if (b.neg) {
        return true
    };
    a.value > b.value
}

public fun lt(a: &Decimal, b: &Decimal): bool {
    if (a.neg && b.neg) {
        return a.value > b.value
    } else if (a.neg) {
        return true
    } else if (b.neg) {
        return false
    };
    a.value < b.value
}

public fun add(a: &Decimal, b: &Decimal): Decimal {
    // -x + -y
    if (a.neg && b.neg) {
        let mut sum = add_internal(a, b);
        sum.neg = true;
        sum
    // -x + y
    } else if (a.neg) {
        sub_internal(b, a)
        
    // x + -y
    } else if (b.neg) {
        sub_internal(a, b)

    // x + y
    } else {
        add_internal(a, b)
    }
}

public fun add_mut(a: &mut Decimal, b: &Decimal) {
    *a = add(a, b);
}

public fun sub(a: &Decimal, b: &Decimal): Decimal {
    // -x - -y
    if (a.neg && b.neg) {
        sub_internal(b, a)
    // -x - y
    } else if (a.neg) {
        let mut sum = add_internal(a, b);
        sum.neg = true;
        sum
    // x - -y
    } else if (b.neg) {
        add_internal(a, b)
    // x - y
    } else {
        sub_internal(a, b)
    }
}

public fun sub_mut(a: &mut Decimal, b: &Decimal) {
    *a = sub(a, b);
}

public fun min(a: &Decimal, b: &Decimal): Decimal {
    if (lt(a, b)) {
        *a
    } else {
        *b
    }
}

public fun max(a: &Decimal, b: &Decimal): Decimal {
    if (gt(a, b)) {
        *a
    } else {
        *b
    }
}


fun add_internal(a: &Decimal, b: &Decimal): Decimal {
    new(a.value + b.value, false)
}

fun sub_internal(a: &Decimal, b: &Decimal): Decimal {
    if (b.value > a.value) {
        new(b.value - a.value, true)
    } else {
        new(a.value - b.value, false)
    }
}

public fun scale_to_decimals(num: &Decimal, current_decimals: u8): u128 {
    if (current_decimals < DECIMALS) {
        return (num.value * pow_10(DECIMALS - current_decimals))
    } else {
        return (num.value / pow_10(current_decimals - DECIMALS))
    }
}


public fun pow_10(e: u8): u128 {
    let mut i = 0;
    let mut result = 1;
    while (i < e) {
        result = result * 10;
        i = i + 1;
    };
    result
}
