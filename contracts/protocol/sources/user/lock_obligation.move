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

    /// unlock the an unhealthy obligation with just a witness key
    /// The key must be the same as the key used to lock the obligation
    /// anyone can unlock it through the module who provided the key
    public fun force_unlock_unhealthy<T: drop>(
        obligation: &mut Obligation,
        market: &mut Market,
        coin_decimals_registry: &CoinDecimalsRegistry,
        x_oracle: &XOracle,
        clock: &Clock,
        key: T
    ) {
        // accrue all interest before any action
        let now = clock::timestamp_ms(clock) / 1000;
        market::accrue_all_interests(market, now);
        obligation::accrue_interests_and_rewards(obligation, market);

        let collaterals_value = collaterals_value_usd_for_liquidation(
            obligation, market, 
            coin_decimals_registry, 
            x_oracle, 
            clock
        );
        let weighted_debts_value = debts_value_usd_with_weight(
            obligation, 
            coin_decimals_registry, 
            market, 
            x_oracle, 
            clock
        );

        assert!(fixed_point32_empower::gt(weighted_debts_value, collaterals_value), error::obligation_cant_forcely_unlocked());

        obligation::set_unlock(obligation, key);

        emit(ObligationUnhealthyUnlocked {
            obligation: object::id(obligation),
            witness: type_name::get<T>(),
        });
    }
}