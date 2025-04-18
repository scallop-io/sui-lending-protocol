import { Transaction, namedPackagesPlugin } from '@mysten/sui/transactions'
import {
    publishResult,
} from '../contracts/protocol';
import { MULTI_SIG_ADDRESS } from './multi-sig';
import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';
import { toBase64 } from '@mysten/sui/utils';
 
export const registerMvr = async () => {
    // register the plugin locally, because the overall library doesn't support sui v1.25.0+ yet
    const plugin = namedPackagesPlugin({ url: 'https://mainnet.mvr.mystenlabs.com' });

    const moveRegistryObjectId = '0x0e5d473a055b6b7d014af557a13ad9075157fdc19b6d51562a18511afd397727';
    const suiNSObjectId = '0xb42008c48a1e16e83a53d646b9279d309cff467f767ff37ac98b5eb34810769f'; // lending@scallop
    const packageInfoId = '0x9c068488c73e5ed5810826464f38934c421ea159869452daca4d2973062ceb85'; // scallop lending package info

    const ptb = new Transaction();
    ptb.addSerializationPlugin(plugin);

    const appCap = ptb.moveCall({
        target: `0x096c9bed5a312b888603f462f22084e470cc8555a275ef61cc12dd83ecf23a04::utils::register`,
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
            ptb.pure.string("contracts/protocol"),
            ptb.pure.string("1b49495d78aea6df7019c4175d26419eda725627"),
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
            ptb.pure.string("lending@scallop/core"),
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
