import { SuiTxBlock } from '@scallop-io/sui-kit';
import { suiKit } from 'sui-elements';
import { decimalsRegistryTxBuilder } from 'contracts/libs/coin_decimals_registry';

async function addDecimalFromCurrency() {
    const coinType = '0x41d587e5336f1c86cad50d38a7136db99333bb9bda91cea4ba69115defeb1402::sui_usde::SUI_USDE';
    const currencyObj = '0x44f0959110bd9e5e91af0483364c42075ac19f173b28f708989f419ef3560576';

    const tx = new SuiTxBlock();
    const [metadata, borrow] = tx.moveCall(
        `0x2::coin_registry::borrow_legacy_metadata`,
        [
            tx.object(currencyObj),
        ],
        [
            coinType
        ]
    )
    decimalsRegistryTxBuilder.registerDecimals(tx, metadata, coinType);
    tx.moveCall(
        `0x2::coin_registry::return_borrowed_legacy_metadata`,
        [
            tx.object(currencyObj),
            metadata,
            borrow,
        ],
        [
            coinType
        ]
    )
    
    const txBytes = await suiKit.signAndSendTxn(tx);
    return txBytes;
}

addDecimalFromCurrency().then(console.log);
