import { Transaction, namedPackagesPlugin } from '@mysten/sui/transactions'
import {
    publishResult,
} from '../contracts/libs/coin_decimals_registry';
import { MULTI_SIG_ADDRESS } from './multi-sig';
import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';
import { toBase64 } from '@mysten/sui/utils';

// CDR (Coin Decimal Registry)

export const packageInfoCreation = async () => {
    // register the plugin locally, because the overall library doesn't support sui v1.25.0+ yet
    const plugin = namedPackagesPlugin({ url: 'https://mainnet.mvr.mystenlabs.com' });

    const ptb = new Transaction();
    ptb.addSerializationPlugin(plugin);

    const mvrMetadataPackage = '@mvr/metadata';

    const packageInfo = ptb.moveCall({
        target: `${mvrMetadataPackage}::package_info::new`,
        arguments: [
            ptb.object(publishResult.upgradeCapId)
        ]
    });

    const display = ptb.moveCall({
        target: `${mvrMetadataPackage}::display::new`,
        arguments: [
            ptb.pure.string('Coin Decimal Registry',),
            ptb.pure.string('EED4C7'), // gradient from
            ptb.pure.string('FFCAAB'), // gradient to
            ptb.pure.string('030F1C'), // text color
        ]
    }
    )

    ptb.moveCall({
        target: `${mvrMetadataPackage}::package_info::set_display`,
        arguments: [
            packageInfo,
            display
        ]
    })

    ptb.moveCall({
        target: `${mvrMetadataPackage}::package_info::transfer`,
        arguments: [
            packageInfo,
            ptb.pure.address(MULTI_SIG_ADDRESS)
        ]
    })

    const suiClient = new SuiClient({
        url: getFullnodeUrl('mainnet'),
    })

    ptb.setSender(MULTI_SIG_ADDRESS);
    const bytes = await ptb.build({
        client: suiClient
    })
    const b64 = toBase64(bytes);
    const resp = await suiClient.dryRunTransactionBlock({
        transactionBlock: b64
    })
    console.log(resp.effects.status);
    console.log(resp.effects);
    return b64
}

packageInfoCreation().then(console.log).catch(console.error).finally(() => process.exit(0));
