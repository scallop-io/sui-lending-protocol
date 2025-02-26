#[test_only]
module x_oracle::switchboard_mock_adapter {
    use x_oracle::price_feed;
    use x_oracle::x_oracle::XOraclePriceUpdateRequest;
    struct SwitchboardRule has drop {}

    #[test_only]
    public fun update_price_as_primary<CoinType>(
        request: &mut XOraclePriceUpdateRequest<CoinType>,
        price: u64,
        last_update: u64,
    ) {
        let price_feed = price_feed::new(price, last_update);
        x_oracle::x_oracle::set_primary_price<CoinType, SwitchboardRule>(
            SwitchboardRule {},
            request,
            price_feed,
        );
    }

    #[test_only]
    public fun update_price_as_secondary<CoinType>(
        request: &mut XOraclePriceUpdateRequest<CoinType>,
        price: u64,
        last_update: u64,
    ) {
        let price_feed = price_feed::new(price, last_update);
        x_oracle::x_oracle::set_secondary_price<CoinType, SwitchboardRule>(
            SwitchboardRule {},
            request,
            price_feed,
        );
    }
}