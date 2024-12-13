module protocol::market_dynamic_keys {
  use std::type_name::TypeName;

  struct BorrowFeeKey has copy, store, drop {
    type: TypeName
  }

  struct BorrowFeeRecipientKey has copy, store, drop {
  }

  struct SupplyLimitKey has copy, store, drop {
    type: TypeName
  }

  struct BorrowLimitKey has copy, store, drop {
    type: TypeName
  } 

  struct IsolatedAssetKey has copy, store, drop {
    type: TypeName
  }  

  public fun borrow_fee_key(type: TypeName): BorrowFeeKey {
    BorrowFeeKey{ type }
  }

  public fun borrow_fee_recipient_key(): BorrowFeeRecipientKey {
    BorrowFeeRecipientKey { }
  }

  public fun supply_limit_key(type: TypeName): SupplyLimitKey {
    SupplyLimitKey { type }
  }

  public fun isolated_asset_key(type: TypeName): IsolatedAssetKey {
    IsolatedAssetKey { type }
  }

  public fun borrow_limit_key(type: TypeName): BorrowLimitKey {
    BorrowLimitKey { type }
  }  
}
