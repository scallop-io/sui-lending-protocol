module mobius_core::token_stats {
  
  use std::type_name::{TypeName, get};
  use std::vector;
  
  struct Stat has store, drop {
    type: TypeName,
    amount: u64,
  }
  
  struct TokenStats has store, drop {
    stats: vector<Stat>
  }
  
  public fun new(): TokenStats {
    TokenStats {
      stats: vector::empty()
    }
  }
  
  public fun increase<T>(self: &mut TokenStats, amount: u64) {
    let typeName = get<T>();
    let(i, len) = (0u64, vector::length(&self.stats));
    while(i < len) {
      let stat = vector::borrow_mut(&mut self.stats, i);
      if (stat.type == typeName) {
        stat.amount = stat.amount + amount;
        return
      }
    };
    vector::push_back(&mut self.stats, Stat { type: typeName, amount })
  }
  
  public fun decrease<T>(self: &mut TokenStats, amount: u64) {
    let typeName = get<T>();
    let(i, len) = (0u64, vector::length(&self.stats));
    while(i < len) {
      let stat = vector::borrow_mut(&mut self.stats, i);
      if (stat.type == typeName) {
        stat.amount = stat.amount - amount;
        return
      }
    };
    assert!(true, 0)
  }
}
