module protocol::obligation_key_display {

	use protocol::obligation::ObligationKey;
	use protocol::version::{Self, Version};
	use std::string;
	use sui::display::{Self, Display};
	use sui::package::{Self, Publisher};
	use sui::transfer;
	use sui::tx_context::{Self, TxContext};

	friend protocol::app;

	// ===== Obligation Key Display Values =====
	const ObligationKeyName: vector<u8> = b"Scallop Obligation Key";
	const ObligationKeyDescription: vector<u8> =
			b"Access key for managing a Scallop lending obligation";
	const ObligationKeyImageUrl: vector<u8> = b"https://nft.apis.scallop.io/render-obligation?obligationKey={id}";
	const ProjectUrl: vector<u8> = b"https://app.scallop.io";
	const Creator: vector<u8> = b"Scallop Labs";
	const Alias: vector<u8> = b"{id}";

	public(friend) fun init_display(
		publisher: &Publisher,
		ctx: &mut TxContext,
	) {
		let sender = tx_context::sender(ctx);
		let display_keys = vector[
			string::utf8(b"name"),
			string::utf8(b"description"),
			string::utf8(b"image_url"),
			string::utf8(b"project_url"),
			string::utf8(b"creator"),
			string::utf8(b"alias"),
		];

		let display_values = vector[
			string::utf8(ObligationKeyName),
			string::utf8(ObligationKeyDescription),
			string::utf8(ObligationKeyImageUrl),
			string::utf8(ProjectUrl),
			string::utf8(Creator),
			string::utf8(Alias),
		];

		let display = display::new_with_fields<ObligationKey>(
			publisher,
			display_keys,
			display_values,
			ctx,
		);
		display::update_version(&mut display);
		transfer::public_transfer(display, sender);
	}

	public fun update_alias(
		version: &Version,
		obligation_key: &ObligationKey,
		display: &mut Display<ObligationKey>,
		new_alias: vector<u8>,
		_ctx: &mut TxContext,
	) {
		// check version
		version::assert_current_version(version);

		display::edit<ObligationKey>(
			display,
			string::utf8(b"alias"),
			string::utf8(new_alias)
		);
		display::update_version(display);
	}
}

