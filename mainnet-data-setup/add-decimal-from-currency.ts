import { SuiTxBlock } from '@scallop-io/sui-kit';
import { suiKit } from 'sui-elements';
import { decimalsRegistryTxBuilder } from 'contracts/libs/coin_decimals_registry';

async function addDecimalFromCurrency() {
    const coinType = '0x44f838219cf67b058f3b37907b655f226153c18e33dfcd0da559a844fea9b1c1::usdsui::USDSUI';
    const currencyObj = '0x535e826a2acddab687c81cb6c6166553b479f61a9023800ec0020baba8d94731';

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
