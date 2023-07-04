module scallop_liquidator::cetus_util {

  use cetus_clmm::pool::{ Pool, calculate_swap_result, calculated_swap_result_amount_in, fee_rate };
  use cetus_clmm::clmm_math::fee_rate_denominator;

  /// Check if liquidation would be profitable when using the cetus pool with single swap.
  ///
  /// # Arguments
  /// pool: The cetus pool to use for the liquidation.
  /// a2b: true if A = debt, B = collateral. false vice versa.
  /// debt_amount: The amount of debt to liquidate.
  /// collateral_amount: The amount of collateral to recieve from the liquidation.
  ///
  /// # Returns
  /// returns true if the liquidation would be profitable, false otherwise.
  ///
  /// # Example
  /// debt is of type A, collateral is of type B.
  /// a2b = false
  /// debt_amount = 100
  /// collateral_amount = 1000
  /// if it requires 900 collateral to exchange for 100 debt, then it is profitable.
  /// if it requires 1100 collateral to exchange for 100 debt, then it is not profitable.
  public fun is_liquidation_profitable<A ,B>(
    pool: &Pool<A, B>,
    a2b: bool, // true if A = debt, B = collateral. false vice versa.
    debt_amount: u64,
    collateral_amount: u64,
  ): bool {
    let by_amount_in = false;
    let swap_result = calculate_swap_result(
      pool,
      a2b,
      by_amount_in,
      debt_amount,
    );
    let collateral_amount_in = calculated_swap_result_amount_in(&swap_result);
    collateral_amount_in <= collateral_amount
  }

  /// Check if liquidation would be profitable when using the cetus pool with double swap.
  /// This is used when DebtType = CollateralType when liquidating.
  ///
  /// # Arguments
  /// pool: The cetus pool to use for the liquidation.
  /// debt_amount: The amount of debt to liquidate.
  /// collateral_amount: The amount of collateral to recieve from the liquidation.
  ///
  /// # Returns
  /// returns true if the liquidation would be profitable, false otherwise.
  ///
  /// # Example
  /// debt_amount = 100
  /// collateral_amount = 110
  /// if it requires 105 debt to exchange for 100 debt, then it is profitable. (Because there're 2 fees when swapping)
  /// if it requires 115 debt to exchange for 100 debt, then it is not profitable.
  ///
  public fun is_liquidation_profitable_with_double_swap<A ,B>(
    pool: &Pool<A, B>,
    debt_amount: u64,
    collateral_amount: u64,
  ): bool {
    let fee_rate = (fee_rate(pool) as u128);
    let fee_rate_denominator = (fee_rate_denominator() as u128);
    let debt_amount = (debt_amount as u128);
    // Because there're 2 fees when swapping, the least collateral amount is calculated as below.
    let least_collateral_amount = debt_amount * fee_rate * 2 / fee_rate_denominator + debt_amount;
    collateral_amount > (least_collateral_amount as u64)
  }
}
