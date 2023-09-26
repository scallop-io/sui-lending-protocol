module ve_token::claim_ve_sca {
  
  use std::option::{Self, Option};
  use std::type_name::TypeName;

  use sui::object::{Self, ID};

  use ve_token::ve_sca::{Self, VeSca, VeScaState, VeScaTreasury};

  const InvalidVeScaIdErr: u64 = 0x1;
  const InvalidRequestErr: u64 = 0x2;

  struct RequestRedeemVeSca {
    for: ID, // id of the VeSca obj
    rule: TypeName,
    amount: Option<u64>,
  }
    
  public fun redeem_ve_sca(
    ve_sca_treasury: &mut VeScaTreasury,
    ve_sca_state: &VeScaState,
    ve_sca: VeSca,
    request_redeem_obj: RequestRedeemVeSca,
  ) {
    let RequestRedeemVeSca {
      for,
      rule,
      amount,
    } = request_redeem_obj;

    assert!(object::id(&ve_sca) == for, InvalidVeScaIdErr);

    assert!(option::is_some(&amount), InvalidRequestErr);
    assert!(ve_sca::model_policy(ve_sca_state, ve_sca::model(&ve_sca)) == rule, InvalidRequestErr);
    let _amount = option::destroy_some(amount);

    ve_sca::redeem_ve_sca(
      ve_sca_treasury,
      ve_sca,
    );
  }

  public fun request_redeem(
    ve_sca: &VeSca,
    ve_sca_state: &VeScaState,
  ): RequestRedeemVeSca {
    RequestRedeemVeSca {
        for: object::id(ve_sca),
        // FIX ME
        rule: ve_sca::model_policy(ve_sca_state, ve_sca::model(ve_sca)),
        amount: option::none(),
    }
  }
}