module scallop_token::sca {

  use sui::tx_context::TxContext;

  struct SCA has drop {}

  fun init(otw: SCA, ctx: &mut TxContext) {
    let decimals = 9u8;
    let symbol = b"SCA";
    let name = b"SCA";
    let description = b"Scallop Token";
    let icon_url_option = url::new_unsafe_from_bytes(
      b"https://raw.githubusercontent.com/scallop-io/scallop-decorations-uri/master/img/SCA.png"
    );
    let (treasuryCap, coinMeta) = coin::create_currency(
      wtiness,
      decimals,
      symbol,
      name,
      description,
      option::some(icon_url_option),
      ctx
    );
    let sender = tx_context::sender(ctx);
    transfer::public_transfer(treasuryCap, sender);
    transfer::public_share_object(coinMeta);
  }
}
