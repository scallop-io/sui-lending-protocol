module borrow_incentive::borrow_incentive {
    use std::type_name;

    use sui::clock::Clock;
    use sui::tx_context::TxContext;

    use protocol::accrue_interest;
    use protocol::market::Market;
    use protocol::obligation::{Self, Obligation, ObligationKey};
    use protocol::obligation_access::ObligationAccessStore;
    use protocol::version::Version;

    use ve_token::ve_sca::{Self, VeSca, VeScaState, VeScaTreasury};

    struct VeScaIssuer has drop {}

    struct VeScaBorrowIncentiveType has drop {}

    struct VeScaBorrowIncentivePolicy has drop {}

    public fun claim_rewards(
        request_redeem_obj: &mut RequestRedeemVeSca,
        ve_sca_treasury: &VeScaTreasury,
        ve_sca: VeSca,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // @FIX ME!!!
        // CHANGE TO THE CORRECT CALCULATION WAY
        let amount = 1;

        ve_sca::store_calculation_result(request_redeem_obj, VeScaBorrowIncentivePolicy{}, amount);
    }

    public fun redeem_borrow_rewards(
        ve_sca_treasury: &mut VeScaTreasury,
        ve_sca_state: &VeScaState,
        version: &Version,
        market: &mut Market,
        obligation: &mut Obligation,
        obligation_key: &ObligationKey,
        obligation_access_store: &ObligationAccessStore,
        clock: &Clock,
        ctx: &mut TxContext
    ): VeSca {
        accrue_interest::accrue_interest_for_market_and_obligation(
            version,
            market,
            obligation,
            clock,
        );

        // @EVALUATE: is it necessary to have conversion rates between rewards point to VeSCA?
        let rewards_point = obligation::rewards_point(obligation);

        obligation::redeem_rewards_point<VeScaIssuer>(
            obligation,
            obligation_key,
            obligation_access_store,
            VeScaIssuer {},
            rewards_point
        );

        let ve_sca = ve_sca::new_ve_sca<VeScaIssuer>(
            VeScaIssuer {},
            ve_sca_state,
            ve_sca_treasury,
            rewards_point,
            type_name::get<VeScaBorrowIncentiveType>(),
            clock,
            ctx,
        );

        ve_sca
    }
}