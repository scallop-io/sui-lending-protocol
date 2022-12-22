module mobius_core::token_stats {
  
  use std::type_name::TypeName;
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
  
  public fun increase(self: &mut TokenStats, typeName: TypeName, amount: u64) {
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
  
  public fun decrease(self: &mut TokenStats, typeName: TypeName,  amount: u64) {
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
  
  public fun stats(stats: &TokenStats): &vector<Stat> {
    &stats.stats
  }
  
  public fun token_type(stat: &Stat): TypeName {
    stat.type
  }
  
  public fun token_amount(stat: &Stat): u64 {
    stat.amount
  }
}
