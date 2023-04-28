module switchboard::math {
    use std::vector;

    const EINCORRECT_STD_DEV: u64 = 0;
    const ENO_LENGTH_PASSED_IN_STD_DEV: u64 = 1;
    const EMORE_THAN_9_DECIMALS: u64 = 2;
    const EINPUT_TOO_LARGE: u64 = 3;

    const MAX_DECIMALS: u8 = 9;
    const POW_10_TO_MAX_DECIMALS: u128 = 1000000000;
    const U128_MAX: u128 = 340282366920938463463374607431768211455;
    const MAX_VALUE_ALLOWED: u128 = 340282366920938463463374607431;

    struct SwitchboardDecimal has copy, drop, store { value: u128, dec: u8, neg: bool }

    public fun max_u128(): u128 {
        U128_MAX
    }

    public fun new(value: u128, dec: u8, neg: bool): SwitchboardDecimal {
        assert!(
            dec <= MAX_DECIMALS,
            EMORE_THAN_9_DECIMALS
        );
        let num = SwitchboardDecimal { value, dec, neg };

        // expand nums out 
        num.value = scale_to_decimals(&num, MAX_DECIMALS);
        num.dec = MAX_DECIMALS;
        num
    }

    public fun pow(base: u64, exp: u8): u128 {
        let result_val = 1u128;
        let i = 0;
        while (i < exp) {
            result_val = result_val * (base as u128);
            i = i + 1;
        };
        result_val
    }

    public fun unpack(num: SwitchboardDecimal): (u128, u8, bool) {
        let SwitchboardDecimal { value, dec, neg } = num;
        (value, dec, neg)
    }

    fun max(a: u8, b: u8): u8 {
        if (a > b) a else b
    }

    fun min(a: u8, b: u8): u8 {
        if (a > b) b else a
    }

    // abs(a - b)
    fun sub_abs_u8(a: u8, b: u8): u8 {
        if (a > b) {
            a - b
        } else {
            b - a
        }
    }

    public fun zero(): SwitchboardDecimal {
      SwitchboardDecimal {
        value: 0,
        dec: 0,
        neg: false
      }
    }

    public fun median(v: &mut vector<SwitchboardDecimal>): SwitchboardDecimal {
        let size = vector::length(v);
        sort_results(v);
        if (size % 2 == 0) {
            let result = zero();
            let lower_idx = vector::borrow(v, (size / 2) - 1);
            let upper_idx = vector::borrow(v, size / 2);
            let sum = add(lower_idx, upper_idx);
            div(&sum, &new(2, 0, false), &mut result);
            result
        } else {
            *vector::borrow(v, size / 2)
        }
    }

    // By reference 

    fun abs_gt(val1: &SwitchboardDecimal, val2: &SwitchboardDecimal): bool {
        val1.value > val2.value
    }

    fun abs_lt(val1: &SwitchboardDecimal, val2: &SwitchboardDecimal): bool {
        val1.value < val2.value
    }

    public fun add(val1: &SwitchboardDecimal, val2: &SwitchboardDecimal): SwitchboardDecimal {
        // -x + -y
        if (val1.neg && val2.neg) {
            let sum = add_internal(val1, val2);
            sum.neg = true;
            sum
        // -x + y
        } else if (val1.neg) {
            sub_internal(val2, val1)
            
        // x + -y
        } else if (val2.neg) {
            sub_internal(val1, val2)

        // x + y
        } else {
            add_internal(val1, val2)
        }
    }

    fun add_internal(val1: &SwitchboardDecimal, val2: &SwitchboardDecimal): SwitchboardDecimal {
        new(val1.value + val2.value, MAX_DECIMALS, false)
    }

    public fun sub(val1: &SwitchboardDecimal, val2: &SwitchboardDecimal): SwitchboardDecimal {
        // -x - -y
        if (val1.neg && val2.neg) {
            let sum = add_internal(val1, val2);
            sum.neg = abs_gt(val1, val2);
            sum
        // -x - y
        } else if (val1.neg) {
            let sum = add_internal(val1, val2);
            sum.neg = true;
            sum
        // x - -y
        } else if (val2.neg) {
            add_internal(val1, val2)

         // x - y
        } else {
            sub_internal(val1, val2)
        }
    }

    fun sub_internal(val1: &SwitchboardDecimal, val2: &SwitchboardDecimal): SwitchboardDecimal {
        if (val2.value > val1.value) {
            new(val2.value - val1.value, MAX_DECIMALS, true)
        } else {
            new(val1.value - val2.value, MAX_DECIMALS, false)
        }
    }


    public fun mul(val1: &SwitchboardDecimal, val2: &SwitchboardDecimal, out: &mut SwitchboardDecimal) {
        let neg = !((val1.neg && val2.neg) || (!val1.neg && !val2.neg));
        mul_internal(val1, val2, out);
        out.neg = neg;
    }

    fun mul_internal(val1: &SwitchboardDecimal, val2: &SwitchboardDecimal, out: &mut SwitchboardDecimal) {
        let multiplied = val1.value * val2.value;
        let new_decimals = val1.dec + val2.dec;
        let multiplied_scaled = if (new_decimals < MAX_DECIMALS) {
            let decimals_underflow = MAX_DECIMALS - new_decimals;
            multiplied * pow_10(decimals_underflow)
        } else if (new_decimals > MAX_DECIMALS) {
            let decimals_overflow = new_decimals - MAX_DECIMALS;
            multiplied / pow_10(decimals_overflow)
        } else {
            multiplied
        };

        out.value = multiplied_scaled;
        out.dec = MAX_DECIMALS;
        out.neg = false;
    }

    public fun div(val1: &SwitchboardDecimal, val2: &SwitchboardDecimal, out: &mut SwitchboardDecimal) {
        let neg = !((val1.neg && val2.neg) || (!val1.neg && !val2.neg));
        let num1_scaled_with_overflow = val1.value * POW_10_TO_MAX_DECIMALS;
        out.value = num1_scaled_with_overflow / val2.value;
        out.dec = MAX_DECIMALS;
        out.neg = neg;
    }

    public fun gt(val1: &SwitchboardDecimal, val2: &SwitchboardDecimal): bool {
        if (val1.neg && val2.neg) {
            return val1.value < val2.value
        } else if (val1.neg) {
            return false
        } else if (val2.neg) {
            return true
        };
        val1.value > val2.value
    }

    public fun lt(val1: &SwitchboardDecimal, val2: &SwitchboardDecimal): bool {
       if (val1.neg && val2.neg) {
            return val1.value > val2.value
        } else if (val1.neg) {
            return true
        } else if (val2.neg) {
            return false
        };
        val1.value < val2.value
    }

    public fun gte(val1: &SwitchboardDecimal, val2: &SwitchboardDecimal): bool {
        if (val1.neg && val2.neg) {
            return val1.value <= val2.value
        } else if (val1.neg) {
            return false
        } else if (val2.neg) {
            return true
        };
        val1.value >= val2.value
    }

    public fun lte(val1: &SwitchboardDecimal, val2: &SwitchboardDecimal): bool {
       if (val1.neg && val2.neg) {
            return val1.value >= val2.value
        } else if (val1.neg) {
            return true
        } else if (val2.neg) {
            return false
        };
        val1.value <= val2.value
    }

    public fun equals(val1: &SwitchboardDecimal, val2: &SwitchboardDecimal): bool {
        let num1 = scale_to_decimals(val1, MAX_DECIMALS);
        let num2 = scale_to_decimals(val2, MAX_DECIMALS);
        num1 == num2 && val1.neg == val2.neg
    }

    public fun scale_to_decimals(num: &SwitchboardDecimal, scale_dec: u8): u128 {
        if (num.dec < scale_dec) {
            return (num.value * pow_10(scale_dec - num.dec))
        } else {
            return (num.value / pow_10(num.dec - scale_dec))
        }
    }

    // add signed u64
    public fun add_u64(i: u64, ineg: bool, j: u64, jneg: bool): (bool, u64) {
        let (neg, val) = if (ineg && jneg) {
            (true, i + j)
        } else if (ineg) {
            if (i > j) {
                (true, i - j)
            } else {
                (false, j - i)
            }
        } else if (jneg) {
            if (j > i) {
                (true, j - i)
            } else {
                (false, i - j)
            }
        } else {
            (false, i + j)
        };
        (neg, val)
    }

    // sub signed u64
    public fun sub_u64(i: u64, ineg: bool, j: u64, jneg: bool): (bool, u64) {
       return (add_u64(i, ineg, j, !jneg))
    }

    public fun lt_u64(i: u64, ineg: bool, j: u64, jneg: bool): bool {
        if (ineg && jneg) {
            return i > j
        } else if (ineg) {
            return true
        } else if (jneg) {
            return false
        };
        i < j
    }

    public fun sort_results(
        vec: &mut vector<SwitchboardDecimal>,
    ) {

        // handle size 0 or 1 vecs
        let n = vector::length(vec);
        if (n < 2) {
            return
        };

        // handle pre-sorted vecs
        let sorted = true;
        let i = 1;
        while (i < n) {
            if (gt(vector::borrow(vec, i - 1), vector::borrow(vec, i))) {
                sorted = false;
                break
            };
            i = i + 1;
        };
        if (sorted) {
            return
        };


        // handle simple case
        sorted = true;
        let i = 0;
        let middle = n / 2;
        while (i < middle) {
            if (gt(vector::borrow(vec, i), vector::borrow(vec, n - i - 1))) {
                vector::swap(vec, i, n - i - 1);
            } else {
                sorted = false;
                break
            };
            
            i = i + 1;
        };
        if (sorted) {
            return
        };

        // handle quicksort
        quick_sort(vec, 0, false, n - 1, false)
    }

    public fun quick_sort(vec: &mut vector<SwitchboardDecimal>, left: u64, left_neg: bool, right: u64, right_neg: bool) {
        let (i, ineg) = (left, left_neg);
        let (j, jneg) = (right, right_neg);

        // get pivot
        let (right_min_left_neg, right_min_left) = sub_u64(right, right_neg, left, left_neg);
        let (_, pivot_index) = add_u64(left, left_neg, right_min_left / 2, right_min_left_neg);
        let pivot = *vector::borrow<SwitchboardDecimal>(vec, pivot_index);
        while (i <= j) {
            while (lt(vector::borrow(vec, i), &pivot)) {
                (ineg, i) = add_u64(i, ineg, 1, false)
            };
            while (gt(vector::borrow(vec, j), &pivot)) {
                (jneg, j) = sub_u64(j, jneg, 1, false);
            };
            if (lt_u64(i, ineg, j, jneg) || (i == j && ineg == jneg)) {
                vector::swap(vec, i, j);
                (ineg, i) = add_u64(i, ineg, 1, false);
                (jneg, j) = sub_u64(j, jneg, 1, false);
            };
        };
        if (lt_u64(left, left_neg, j, jneg)) {
            quick_sort(vec, left, left_neg, j, jneg);
        };
        if (lt_u64(i, ineg, right, right_neg)) {
            quick_sort(vec, i, ineg, right, right_neg);
        };
    }

    // Exponents.
    const F0 : u128 = 1;
    const F1 : u128 = 10;
    const F2 : u128 = 100;
    const F3 : u128 = 1000;
    const F4 : u128 = 10000;
    const F5 : u128 = 100000;
    const F6 : u128 = 1000000;
    const F7 : u128 = 10000000;
    const F8 : u128 = 100000000;
    const F9 : u128 = 1000000000;

    // Programatic way to get a power of 10.
    fun pow_10(e: u8): u128 {
        if (e == 0) {
            F0
        } else if (e == 1) {
            F1
        } else if (e == 2) {
            F2
        } else if (e == 3) {
            F3
        } else if (e == 4) {
            F4
        } else if (e == 5) {
            F5
        } else if (e == 5) {
            F5
        } else if (e == 6) {
            F6
        } else if (e == 7) {
            F7
        } else if (e == 8) {
            F8
        } else if (e == 9) {
            F9
        } else {
            0
        }
    }

    #[test_only]
    fun enforce_order(vec: &vector<SwitchboardDecimal>) {
        let n = vector::length(vec);
        let i = 1;
        while (i < n) {
            assert!(lte(vector::borrow(vec, i - 1), vector::borrow(vec, i)), 0);
            i = i + 1;
        }
    } 

    #[test(account = @0x1)]
    public entry fun test_math() {

        let vec: vector<SwitchboardDecimal> = vector::empty();
        vector::push_back(&mut vec, new(20000012342, 0, false));
        vector::push_back(&mut vec, new(20000012341, 0, false));
        vector::push_back(&mut vec, new(20000012343, 0, false));
        vector::push_back(&mut vec, new(20000012344, 0, false));
        vector::push_back(&mut vec, new(20000012345, 0, false));
        vector::push_back(&mut vec, new(20000012346, 0, false));
        vector::push_back(&mut vec, new(20000012349, 0, false));
        vector::push_back(&mut vec, new(20000012344, 0, false));
        vector::push_back(&mut vec, new(20000012342, 0, false));
        vector::push_back(&mut vec, new(20000012341, 0, false));
        vector::push_back(&mut vec, new(20000012342, 0, false));
        vector::push_back(&mut vec, new(20000012342, 0, false));
        vector::push_back(&mut vec, new(20000012341, 0, false));
        vector::push_back(&mut vec, new(20000012344, 0, false));
        vector::push_back(&mut vec, new(20000012341, 0, false));
        vector::push_back(&mut vec, new(20000012342, 0, false));
        let median = median(&mut vec);
        std::debug::print(&median);


        let vec: vector<SwitchboardDecimal> = vector::empty();
        vector::push_back(&mut vec, new(1, 0, false));
        vector::push_back(&mut vec, new(5, 0, false));
        vector::push_back(&mut vec, new(2, 0, false));
        vector::push_back(&mut vec, new(3, 0, false));
        vector::push_back(&mut vec, new(6, 0, false));
        vector::push_back(&mut vec, new(7, 0, false));
        vector::push_back(&mut vec, new(5, 0, false));
        vector::push_back(&mut vec, new(9, 0, false));
        vector::push_back(&mut vec, new(2, 0, false));
        vector::push_back(&mut vec, new(3, 0, false));
        vector::push_back(&mut vec, new(1000, 0, false));
        vector::push_back(&mut vec, new(23412, 0, false));
        vector::push_back(&mut vec, new(512, 0, true));
        vector::push_back(&mut vec, new(11, 0, false));
        vector::push_back(&mut vec, new(222, 0, false));
        vector::push_back(&mut vec, new(31245, 0, false));
        sort_results(&mut vec);
        std::debug::print(&vec);
        enforce_order(&vec);

        let vec: vector<SwitchboardDecimal> = vector::empty();
        vector::push_back(&mut vec, new(1, 9, false));
        vector::push_back(&mut vec, new(5, 9, false));
        vector::push_back(&mut vec, new(2, 9, false));
        vector::push_back(&mut vec, new(3, 9, true));
        vector::push_back(&mut vec, new(6, 9, false));
        vector::push_back(&mut vec, new(7, 9, false));
        vector::push_back(&mut vec, new(5, 9, true));
        vector::push_back(&mut vec, new(0, 9, false));
        vector::push_back(&mut vec, new(2, 9, true));
        vector::push_back(&mut vec, new(0, 9, true));
        vector::push_back(&mut vec, new(1999, 9, false));
        vector::push_back(&mut vec, new(23412, 9, false));
        vector::push_back(&mut vec, new(512, 9, true));
        vector::push_back(&mut vec, new(11, 9, false));
        vector::push_back(&mut vec, new(222, 9, false));
        vector::push_back(&mut vec, new(31245, 0, false));
        sort_results(&mut vec);
        std::debug::print(&vec);
        enforce_order(&vec);


        let vec: vector<SwitchboardDecimal> = vector::empty();
        vector::push_back(&mut vec, new(1, 9, false));
        sort_results(&mut vec);
        std::debug::print(&vec);
        enforce_order(&vec);


        let vec: vector<SwitchboardDecimal> = vector::empty();
        vector::push_back(&mut vec, new(1, 9, false));
        vector::push_back(&mut vec, new(5, 9, true));
        sort_results(&mut vec);
        std::debug::print(&vec);
        enforce_order(&vec);


        let vec: vector<SwitchboardDecimal> = vector::empty();
        vector::push_back(&mut vec, new(1, 9, false));
        vector::push_back(&mut vec, new(5, 9, true));
        vector::push_back(&mut vec, new(23412, 9, false));
        sort_results(&mut vec);
        std::debug::print(&vec);
        enforce_order(&vec);


        let vec: vector<SwitchboardDecimal> = vector::empty();
        vector::push_back(&mut vec, new(10, 0, false));
        vector::push_back(&mut vec, new(1, 0, false));
        let expected_median = new(55, 1, false);
        let median = median(&mut vec);
        std::debug::print(&median);
        assert!(median.value == expected_median.value, 0);

        std::debug::print(&vec);
        enforce_order(&vec);
    }
}
