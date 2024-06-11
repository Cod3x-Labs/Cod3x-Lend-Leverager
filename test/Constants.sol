// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";

contract Constants {
    address public immutable addressesProvider;
    address public immutable weth;

    constructor() {

        // Ethereum mainnet (AAVE V2)
        // if (block.chainid == 1) {
        addressesProvider = address(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);
        weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // weth
        // }

        // // Polygon (AAVE V2)
        // else if (block.chainid == 137) {
        //     addressesProvider = address(0xd05e3E715d945B59290df0ae8eF85c1BdB684744);
        //     weth = address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270); // wmatic
        // }

        // // Optimism (Granary) 
        // else if (block.chainid == 10) {
        //     addressesProvider = address(0xdDE5dC81e40799750B92079723Da2acAF9e1C6D6);
        //     weth = address(0x4200000000000000000000000000000000000006); // weth
        // }

        // Arbitrum (Granary)
        // else if (block.chainid == 42161) {
        //     addressesProvider = address(0x642cc899652B068D1bED786c4B060Ec1027D1563);
        //     weth = address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1); // weth
        // }
    }

}

// arb weth 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1