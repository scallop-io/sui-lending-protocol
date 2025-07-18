/// @title This module is designed to let liquidator unlock unhealthy obligation for later liquidation
/// @author Scallop Labs
/// @notice When obligation is locked, no operation is allowed on it.
///         But there's special case: when obligation becomes unhealthy, liquidator should be able to enforce the unlock for liquidation.
module protocol::lock_obligation {

    use std::type_name::{Self, TypeName};

    use sui::clock::{Self, Clock};
    use sui::event::emit;
    use sui::object::{Self, ID};

    use math::fixed_point32_empower;
    use coin_decimals_registry::coin_decimals_registry::CoinDecimalsRegistry;
    use x_oracle::x_oracle::XOracle;

    use protocol::obligation::{Self, Obligation};
    use protocol::debt_value::debts_value_usd_with_weight;
    use protocol::collateral_value::collaterals_value_usd_for_liquidation;
    use protocol::market::{Self, Market};
    use protocol::error;
    
    struct ObligationUnhealthyUnlocked has copy, drop {
        obligation: ID,
        witness: TypeName,
    }

    /// @notice Unlock the an unhealthy obligation
    /// @dev Anyone can unlock the obligation if it becomes unhealthy.
    ///      Another authorized contract should have a method which call this function to allow for liquidator to unlock the obligation.
    /// @param obligation The obligation to be unlocked
    /// @param market The Scallop market object, it contains base assets, and related protocol configs
    /// @param coin_decimals_registry The registry object which contains the decimal information of coins
    /// @param x_oracle The x-oracle object which provides the price of assets
    /// @param clock The SUI system Clock object
    /// @param key The witness issued by the authorized contract
    public fun force_unlock_unhealthy<T: drop>(
        obligation: &mut Obligation,
        market: &mut Market,
        coin_decimals_registry: &CoinDecimalsRegistry,
        x_oracle: &XOracle,
        clock: &Clock,
        key: T
    ) {
        // Unlock the obligation, this also does the necessary check if the witness is correct
        obligation::set_unlock(obligation, key);

        // accrue all interest before any action
        let now = clock::timestamp_ms(clock) / 1000;
        market::accrue_all_interests(market, now);
        obligation::accrue_interests(obligation, market);

        // calculate the value of collaterals in the context of liquidation
        // collateral value is discounted with liquidation factor
        // 1000$ of market value asset, with 90% liquidation factor, will be counted as 900$
        let collaterals_value = collaterals_value_usd_for_liquidation(
            obligation, market, 
            coin_decimals_registry, 
            x_oracle, 
            clock
        );
        // calculate the value of debts in the context of liquidation
        // debt value is boosted by the borrow weight
        // 1000$ of market value debt, with 1.5x borrow weight, will be counted as 1500$
        let weighted_debts_value = debts_value_usd_with_weight(
            obligation, 
            coin_decimals_registry, 
            market, 
            x_oracle, 
            clock
        );

        // Make sure the debt value is bigger than collateral value in context of liquidation
        assert!(fixed_point32_empower::gt(weighted_debts_value, collaterals_value), error::obligation_cant_forcely_unlocked());

        // Emit the unlock event
        emit(ObligationUnhealthyUnlocked {
            obligation: object::id(obligation),
            witness: type_name::get<T>(),
        });
    }
}