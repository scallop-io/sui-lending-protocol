module switchboard::utils {
    use sui::table_vec::{Self, TableVec};
    use sui::bag::{Self, Bag};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{TxContext};
    use std::vector;
    use std::type_name;
    use std::ascii;

    // swap remove for table vec
    public fun swap_remove<T: drop + store>(
        v: &mut TableVec<T>,
        idx: u64,
    ) {
        let last = table_vec::pop_back(v);
        let el = table_vec::borrow_mut(v, idx);
        *el = last;
    }

    // copy a portion of a vector into a new vector
    public fun slice(vec: &vector<u8>, start_index: u64, end_index: u64): vector<u8> {
        let result: vector<u8> = vector::empty();
        let max_index: u64 = vector::length(vec);
        let slice_end_index: u64 = if (end_index > max_index) { max_index } else { end_index };
        let i = start_index;
        while (i < slice_end_index) {
            let byte = vector::borrow(vec, i);
            vector::push_back(&mut result, *byte);
            i = i + 1;
        };
        result
    }

    // Escrow util functions

    public fun escrow_deposit<CoinType>(
        escrow_bag: &mut Bag, 
        addr: address,
        coin: Coin<CoinType>
    ) {
        if (!bag::contains_with_type<address, Balance<CoinType>>(escrow_bag, addr)) {
            let escrow = balance::zero<CoinType>();
            coin::put(&mut escrow, coin);
            bag::add<address, Balance<CoinType>>(escrow_bag, addr, escrow);
        } else {
            let escrow = bag::borrow_mut<address, Balance<CoinType>>(escrow_bag, addr);
            coin::put(escrow, coin);
        }
    }

    public fun escrow_withdraw<CoinType>(
        escrow_bag: &mut Bag, 
        addr: address,
        amount: u64,
        ctx: &mut TxContext,
    ): Coin<CoinType> {
        let escrow = bag::borrow_mut<address, Balance<CoinType>>(escrow_bag, addr);
        coin::take(escrow, amount, ctx)
    }

    public fun escrow_balance<CoinType>(
        escrow_bag: &Bag, 
        key: address
    ): u64 {
        if (!bag::contains_with_type<address, Balance<CoinType>>(escrow_bag, key)) {
            0
        } else {
            let escrow = bag::borrow<address, Balance<CoinType>>(escrow_bag, key);
            balance::value(escrow)
        }
    }

    public fun type_of<T>(): vector<u8> {
        ascii::into_bytes(type_name::into_string(type_name::get<T>()))
    }

    // get mr_enclave and report body
    public fun parse_sgx_quote(quote: &vector<u8>): (vector<u8>, vector<u8>) {


        // snag relevant data from the quote
        let mr_enclave: vector<u8> = slice(quote, 112, 144);
        let report_body: vector<u8> = slice(quote, 368, 432);

        // Parse the SGX quote header
        // let _version: u16 = u16_from_le_bytes(&slice(&quote, 0, 2));
        // let _sign_type: u16 = u16_from_le_bytes(&slice(&quote, 2, 4));
        // let _epid_group_id: vector<u8> = slice(&quote, 4, 8);
        // let _qe_svn: u16 = u16_from_le_bytes(&slice(&quote, 8, 10));
        // let _pce_svn: u16 = u16_from_le_bytes(&slice(&quote, 10, 12));
        // let _qe_vendor_id: vector<u8> = slice(&quote, 12, 28);
        // let _user_data: vector<u8> = slice(&quote, 16, 48);

        // Parse the SGX &quote body
        // let report: vector<u8> = slice(&quote, 48, 48 + 384);
        // let _cpu_svn: vector<u8> = slice(&report, 0, 16);
        // let _misc_select: vector<u8> = slice(&report, 16, 20);
        // let _reserved1: vector<u8> = slice(&report, 20, 48);
        // let _attributes: vector<u8> = slice(&report, 48, 64);
        // let mr_enclave: vector<u8> = slice(&report, 64, 96);
        // let _reserved2: vector<u8> = slice(&report, 96, 128);
        // let _mr_signer: vector<u8> = slice(&report, 128, 160);
        // let _reserved3: vector<u8> = slice(&report, 160, 256);
        // let _isv_prod_id: u16 = u16_from_le_bytes(&slice(&report, 256, 258));
        // let _isv_svn: u16 = u16_from_le_bytes(&slice(&report, 258, 260));
        // let _reserved4: vector<u8> = slice(&report, 260, 320);
        // let report_body: vector<u8> = slice(&report, 320, 384);

        // print everything
        // std::debug::print(&_version);
        // std::debug::print(&_sign_type);
        // std::debug::print(&_epid_group_id);
        // std::debug::print(&_qe_svn);
        // std::debug::print(&_pce_svn);
        // std::debug::print(&_qe_vendor_id);
        // std::debug::print(&_user_data);
        // std::debug::print(&report);
        // std::debug::print(&_cpu_svn);
        // std::debug::print(&_misc_select);
        // std::debug::print(&_reserved1);
        // std::debug::print(&_attributes);
        // std::debug::print(&mr_enclave);
        // std::debug::print(&_reserved2); 
        // std::debug::print(&_mr_signer);
        // std::debug::print(&_reserved3);
        // std::debug::print(&_isv_prod_id);
        // std::debug::print(&_isv_svn);
        // std::debug::print(&_reserved4);
        // std::debug::print(&_report_body);

        // Return the mr_enclave value
        (mr_enclave, report_body)
    }

    public fun u16_from_le_bytes(bytes: &vector<u8>): u16 {
        ((*(vector::borrow(bytes, 0)) as u16) <<  0) +
        ((*(vector::borrow(bytes, 1)) as u16) <<  8) 
    }


    public fun u32_from_le_bytes(bytes: &vector<u8>): u32 {
        ((*(vector::borrow(bytes, 0)) as u32) <<  0) +
        ((*(vector::borrow(bytes, 1)) as u32) <<  8) +
        ((*(vector::borrow(bytes, 2)) as u32) << 16) +
        ((*(vector::borrow(bytes, 3)) as u32) << 24)
    }

    #[test(account = @0x1)]
    public entry fun text_sgx_quote_parse() {
        let quote = x"030002000000000002000700939a7233f79c4ca9940a0db3957f06077f98317524f7aef6babe78e91e20d5900000000002020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007000000000000001b00000000000000d40c35b716c9ef1715d26100bb5e152d5045543017dacfcb492697028985cb7c00000000000000000000000000000000000000000000000000000000000000009affcfae47b848ec2caf1c49b4b283531e1cc425f93582b36806e52a43d78d1a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000fc0300002e70000a8e51e5866efc4dcf6a2657940422ff3ddfc899c49e1ee1d0cf194c1b1ce65be5a8395f6cd835f321e072db9f551090c1bd37d8fdb8fe5950c861a0834106e51aadd59b2e3720e40f954837e45ba63207b48140650beac5d7797bdedbc35bd6023814c0e84c7e1eb947ec971a8c925ffe9fb42d9013423bcc0e70c3bf02020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000015000000000000000300000000000000c0dababdfbb16e99dba2fce241092d6030f657e737f49adeb827ec5adae4f29000000000000000000000000000000000000000000000000000000000000000008c4f5775d796503e96137f77c68a829a0056ac8ded70140b081b094490c57bff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e22512a58807489f138603fc7abf3e7514a1061fa0b7150a6ba4f7a10f5670320000000000000000000000000000000000000000000000000000000000000000e7bd2972d69a86b3e4dafdfa1a0b1ca20c3feaf0c9fa2b3a8c57537011184d770cea1f6e7151627ff222859f7cf9b103e1a3fc37e239997d037a2255c8b1a2b42000000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f030094010000b1c840c5df23245491da2469c667a6b66c2db2dc1e141b78016d30a569c087b9eb1fcbd3b5c1cb06df82a0c4707d2b78cb9d0cdd7df755df16a0f82e1997b5b9553ba2c49a18b3b1505a6d385180361126dcbfc6a4a4a172dd6c31b74aea32fe4734222d21aeeceff67f5d1f1d415851ac1c8ceb776af8dfc5212c04059dc2d8180fe188adb4bd21458d721cee3531f35fa7fc36f25bc6e14b3993dab19ffb250e9ee9495bd92f47739f0cab2f77dc30e97790f30be6d1add0ea60061460501abf28c339ccd0f9f479f9091ac40492c4038eb7d6831d32ef217dccc2bac6a77ef0777c69c247b5263b9645aebfef0fa814e634a9c73f3b6b3df46b66e3af31e3759141f08b4880d5bef295b33af99b14739078832785b7c07e35de62ff4914100abeee222625105fb8038b819bb73318137d54bc0bc46f0112e7e1b6a94d4c13af9a4d2092e0880687239388d2735909032b3baa044a8e9d5400ee9f993e4601368f13e4323bebc7a0e6f5ad7e5cb19b02923f34918bf71aabf07537438e00600202000000000000000000000000000007000000";
        // get mr enclave
        std::debug::print(&quote);

        let (mr_enclave, _report_data) = parse_sgx_quote(&quote);
        std::debug::print(&mr_enclave);

    }
}
