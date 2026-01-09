import {
    SupportedBaseAssets,
    coinDecimals,
} from './chain-data';


export const BorrowLimits: Record<SupportedBaseAssets, number> = {
    sui: 1e8 * Math.pow(10, coinDecimals.sui),
    wormholeUsdc: 0 * Math.pow(10, coinDecimals.wormholeUsdc),
    wormholeUsdt: 0 * Math.pow(10, coinDecimals.wormholeUsdt),
    sca: 15e6 * Math.pow(10, coinDecimals.sca),
    afSui: 1e6 * Math.pow(10, coinDecimals.afSui),
    haSui: 10e6 * Math.pow(10, coinDecimals.haSui), // 10M
    vSui: 0 * Math.pow(10, coinDecimals.vSui),
    cetus: 2e6 * Math.pow(10, coinDecimals.cetus),
    wormholeEth: 0 * Math.pow(10, coinDecimals.wormholeEth),
    wormholeBtc: 0 * Math.pow(10, coinDecimals.wormholeBtc),
    sbwBTC: 20 * Math.pow(10, coinDecimals.sbwBTC),
    xBTC: 10 * Math.pow(10, coinDecimals.xBTC),
    wormholeSol: 2e4 * Math.pow(10, coinDecimals.wormholeSol),
    nativeUsdc: 5e7 * Math.pow(10, coinDecimals.nativeUsdc),
    sbEth: 5e3 * Math.pow(10, coinDecimals.sbEth),
    deep: 180_000_000 * Math.pow(10, coinDecimals.deep),
    fud: 0 * Math.pow(10, coinDecimals.fud),
    fdusd: 5e6 * Math.pow(10, coinDecimals.fdusd), // 5M
    sbUsdt: 1e7 * Math.pow(10, coinDecimals.sbUsdt),
    blub: 0 * Math.pow(10, coinDecimals.blub),
    mUsd: 2e6 * Math.pow(10, coinDecimals.mUsd), // 2M
    ns: 5e6 * Math.pow(10, coinDecimals.ns), // 5M
    usdy: 5e6 * Math.pow(10, coinDecimals.usdy), // 5M
    wal: 18_000_000 * Math.pow(10, coinDecimals.wal), // 18M
    haedal: 5_000_000 * Math.pow(10, coinDecimals.haedal), // 5M
    wWal: 8_000_000 * Math.pow(10, coinDecimals.wWal), // 8M
    haWal: 8_000_000 * Math.pow(10, coinDecimals.haWal), // 8M
    lofi: 0 * Math.pow(10, coinDecimals.lofi),
}
