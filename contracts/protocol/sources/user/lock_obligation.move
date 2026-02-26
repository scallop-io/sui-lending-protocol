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
    use protocol::version::{Self, Version};
    
    struct ObligationUnhealthyUnlocked has copy, drop {
        obligation: ID,
        witness: TypeName,
    }

    struct ObligationForceUnlocked has copy, drop {
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
        _obligation: &mut Obligation,
        _market: &mut Market,
        _coin_decimals_registry: &CoinDecimalsRegistry,
        _x_oracle: &XOracle,
        _clock: &Clock,
        _key: T
    ) {
        abort 0;
    }

    public fun force_unlock<T: drop>(
        version: &Version,
        obligation: &mut Obligation,
        key: T
    ) {
        // check if version is supported
        version::assert_current_version(version);
        
        // Unlock the obligation, this also does the necessary check if the witness is correct
        obligation::set_unlock(obligation, key);

        // Emit the unlock event
        emit(ObligationForceUnlocked {
            obligation: object::id(obligation),
            witness: type_name::get<T>(),
        });
    }
}