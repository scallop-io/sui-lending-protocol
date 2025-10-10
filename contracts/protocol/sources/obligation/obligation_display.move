module protocol::obligation_key_display {

	use protocol::obligation::ObligationKey;
	use std::string;
	use sui::display;
	use sui::package;
	use sui::transfer;
	use sui::tx_context::{Self, TxContext};

	// ===== Obligation Key Display Values =====
	const ObligationKeyName: vector<u8> = b"Scallop Obligation Key";
	const ObligationKeyDescription: vector<u8> =
			b"Access key for managing a Scallop lending obligation";
	// TODO: add image url
	const ObligationKeyImageUrl: vector<u8> = b"https://";
	const ProjectUrl: vector<u8> = b"https://scallop.io";
	const Creator: vector<u8> = b"Scallop Protocol";

	struct OBLIGATION_KEY_DISPLAY has drop {}

	fun init(otw: OBLIGATION_KEY_DISPLAY, ctx: &mut TxContext) {
		let publisher = package::claim(otw, ctx);
		let sender = tx_context::sender(ctx);

		let display_keys = vector[
			string::utf8(b"name"),
			string::utf8(b"description"),
			string::utf8(b"image_url"),
			string::utf8(b"project_url"),
			string::utf8(b"creator"),
		];

		let display_values = vector[
			string::utf8(ObligationKeyName),
			string::utf8(ObligationKeyDescription),
			string::utf8(ObligationKeyImageUrl),
			string::utf8(ProjectUrl),
			string::utf8(Creator),
		];

		let display = display::new_with_fields<ObligationKey>(
			&publisher,
			display_keys,
			display_values,
			ctx,
		);
		display::update_version(&mut display);

		transfer::public_transfer(publisher, sender);
		transfer::public_transfer(display, sender);
	}

	public fun update_display_name(
		_obligation_key: &mut ObligationKey,
		display: &mut display::Display<ObligationKey>,
		new_name: vector<u8>,
		_ctx: &mut TxContext
	) {
		display::edit<ObligationKey>(
			display,
			string::utf8(b"name"),
			string::utf8(new_name)
		);
	}

	public fun update_display_description(
		_obligation_key: &mut ObligationKey,
		display: &mut display::Display<ObligationKey>,
		new_description: vector<u8>,
		_ctx: &mut TxContext
	) {
		display::edit<ObligationKey>(
			display,
			string::utf8(b"description"),
			string::utf8(new_description)
		);
	}
}

