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
    haSui: 5e6 * Math.pow(10, coinDecimals.haSui), // 5M
    vSui: 5e4 * Math.pow(10, coinDecimals.vSui),
    cetus: 2e6 * Math.pow(10, coinDecimals.cetus),
    wormholeEth: 0 * Math.pow(10, coinDecimals.wormholeEth),
    wormholeBtc: 0 * Math.pow(10, coinDecimals.wormholeBtc),
    sbwBTC: 20 * Math.pow(10, coinDecimals.sbwBTC),
    wormholeSol: 2e4 * Math.pow(10, coinDecimals.wormholeSol),
    nativeUsdc: 5e7 * Math.pow(10, coinDecimals.nativeUsdc),
    sbEth: 5e3 * Math.pow(10, coinDecimals.sbEth),
    deep: 180_000_000 * Math.pow(10, coinDecimals.deep),
    fud: 2_400_000_000_000 * Math.pow(10, coinDecimals.fud),
    fdusd: 950_000 * Math.pow(10, coinDecimals.fdusd),
    sbUsdt: 1e7 * Math.pow(10, coinDecimals.sbUsdt),
    blub: 24e12 * Math.pow(10, coinDecimals.blub), // 24T
    mUsd: 2e6 * Math.pow(10, coinDecimals.mUsd), // 2M
    ns: 5e6 * Math.pow(10, coinDecimals.ns), // 5M
    usdy: 5e6 * Math.pow(10, coinDecimals.usdy), // 5M
}
