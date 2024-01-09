module protocol::market_dynamic_keys {
  use std::type_name::TypeName;

  struct BorrowFeeKey has copy, store, drop {
    type: TypeName
  }

  struct BorrowFeeRecipientKey has copy, store, drop {
  }

  public fun borrow_fee_key(type: TypeName): BorrowFeeKey {
    BorrowFeeKey{ type }
  }

  public fun borrow_fee_recipient_key(): BorrowFeeRecipientKey {
    BorrowFeeRecipientKey { }
  }
}
