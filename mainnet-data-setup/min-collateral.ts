import {
    coinDecimals,
    SupportedCollaterals,
} from './chain-data';

export const MinCollaterals: Record<SupportedCollaterals, number> = {
    sui: 10 ** (coinDecimals.sui - 1), // 0.1 sui
    wormholeUsdc: 10 ** (coinDecimals.wormholeUsdc - 2), // 0.01 USDC
    wormholeUsdt: 10 ** (coinDecimals.wormholeUsdt - 2), // 0.01 USDT
    sca: 10 ** coinDecimals.sca, // 1 SCA
    afSui: 10 ** (coinDecimals.afSui - 1), // 0.1 afSUI
    haSui: 10 ** (coinDecimals.haSui - 1), // 0.1 haSUI
    vSui: 10 ** (coinDecimals.vSui - 1), // 0.1 haSUI
    cetus: 10 ** (coinDecimals.cetus), // 1 CETUS
    wormholeEth: 10 ** (coinDecimals.wormholeEth - 3), // 0.001 ETH
    wormholeBtc: 10 ** (coinDecimals.wormholeBtc - 6), // 0.000001 Btc
    sbwBTC: 10 ** (coinDecimals.sbwBTC - 6), // 0.000001 Btc
    xBTC: 10 ** (coinDecimals.xBTC - 6), // 0.000001 Btc
    wormholeSol: 10 ** (coinDecimals.wormholeSol - 3), // 0.001 Sol
    nativeUsdc: 10 ** (coinDecimals.nativeUsdc - 2), // 0.01 USDC
    sbEth: 10 ** (coinDecimals.sbEth - 3), // 0.001 SBETH
    deep: 10 ** (coinDecimals.deep + 1), // 10 DEEP
    fdusd: 10 ** (coinDecimals.fdusd - 2), // 0.01 FDUSD
    sbUsdt: 10 ** (coinDecimals.sbUsdt - 2), // 0.01 USDT
    usdy: 10 ** (coinDecimals.usdy - 2), // 0.01 USDY
    wal: 10 ** (coinDecimals.wal - 1), // 0.1 WAL
    haedal: 10 ** coinDecimals.haedal, // 1 HAEDAL
    wWal: 10 ** (coinDecimals.wWal - 1), // 0.1 WWAL
    haWal: 10 ** (coinDecimals.haWal - 1), // 0.1 HAWAL
}