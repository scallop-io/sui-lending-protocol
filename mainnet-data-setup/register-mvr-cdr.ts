import { Transaction, namedPackagesPlugin } from '@mysten/sui/transactions'
import { MULTI_SIG_ADDRESS } from './multi-sig';
import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';
import { toBase64 } from '@mysten/sui/utils';
 
export const registerMvr = async () => {
    // register the plugin locally, because the overall library doesn't support sui v1.25.0+ yet
    const plugin = namedPackagesPlugin({ url: 'https://mainnet.mvr.mystenlabs.com' });

    const moveRegistryObjectId = '0x0e5d473a055b6b7d014af557a13ad9075157fdc19b6d51562a18511afd397727';
    const suiNSObjectId = '0x784682ee9e1c6e75266adb9bc1c63bc7da42d423ecba10deef091554a6dfcbae'; // coin-decimal-registry@scallop
    const packageInfoId = '0xe2079634fa9f39df4ad01f455458ebba1e53c41b5dbd4776f354b52334587a6b'; // scallop Coin Decimal Registry package info

    const ptb = new Transaction();
    ptb.addSerializationPlugin(plugin);

    const appCap = ptb.moveCall({
        target: `@mvr/subnames-proxy::utils::register`,
        arguments: [
            ptb.object(moveRegistryObjectId),
            ptb.object(suiNSObjectId),
            ptb.pure.string('core'),
            ptb.object.clock(),
        ]
    });

    // git versioning
    const git = ptb.moveCall({
        target: `@mvr/metadata::git::new`,
        arguments: [
            ptb.pure.string("https://github.com/scallop-io/sui-lending-protocol"),
            ptb.pure.string("contracts/libs/coin_decimals_registry"),
            ptb.pure.string("08c01c31a13587680524579b5f29c0dc49e8da01"),
        ],
    });

    ptb.moveCall({
        target: `@mvr/metadata::package_info::set_git_versioning`,
        arguments: [
            ptb.object(packageInfoId),
            ptb.pure.u64('1'),
            git,
        ],
    });

    // set metadata
    ptb.moveCall({
        target: `@mvr/core::move_registry::set_metadata`,
        arguments: [
          ptb.object(moveRegistryObjectId),
          ptb.object(appCap),
          ptb.pure.string("description"),
          ptb.pure.string(
            "Scallop is a next-generation Money Market on Sui. Scallop is designed to be fast, secure, and efficient.",
          ),
        ],
    });
    
    ptb.moveCall({
        target: `@mvr/core::move_registry::set_metadata`,
        arguments: [
            ptb.object(moveRegistryObjectId),
            ptb.object(appCap),
            ptb.pure.string("icon_url"),
            ptb.pure.string("https://vrr7y7aent4hea3r444jrrsvgvgwsz6zi2r2vv2odhgfrgvvs6iq.arweave.net/rGP8fARs-HIDcec4mMZVNU1pZ9lGo6rXThnMWJq1l5E"),
        ],
    });

    ptb.moveCall({
        target: `@mvr/core::move_registry::set_metadata`,
        arguments: [
            ptb.object(moveRegistryObjectId),
            ptb.object(appCap),
            ptb.pure.string("documentation_url"),
            ptb.pure.string("https://docs.scallop.io"),
        ],
    });    

    ptb.moveCall({
        target: `@mvr/core::move_registry::set_metadata`,
        arguments: [
            ptb.object(moveRegistryObjectId),
            ptb.object(appCap),
            ptb.pure.string("homepage_url"),
            ptb.pure.string("https://scallop.io"),
        ],
    });


    // set default metadata
    ptb.moveCall({
        target: "@mvr/metadata::package_info::set_metadata",
        arguments: [
            ptb.object(packageInfoId),
            ptb.pure.string("default"),
            ptb.pure.string("coin-decimal-registry@scallop/core"),
        ],
    });

    // linked
    ptb.moveCall({
        target: `@mvr/core::move_registry::assign_package`,
        arguments: [
            ptb.object(moveRegistryObjectId),
            ptb.object(appCap),
            ptb.object(packageInfoId),
        ],
    });

    ptb.transferObjects(
        [appCap],
        MULTI_SIG_ADDRESS
    );

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

registerMvr().then(console.log).catch(console.error).finally(() => process.exit(0));
