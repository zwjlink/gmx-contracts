// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./interfaces/IPancakeFactory.sol";

//用于创建和管理交易对，
contract PancakeFactory is IPancakeFactory {
    address public btc;
    address public bnb;
    address public busd;

    address public bnbBusdPair;
    address public btcBnbPair;

    //构造函数
    constructor(address[] memory _addresses) public {
        btc = _addresses[0];
        bnb = _addresses[1];
        busd = _addresses[2];

        bnbBusdPair = _addresses[3]; // BNB-BUSD
        btcBnbPair = _addresses[4]; // BTC-BNB
    }

    //获取交易对
    function getPair(address tokenA, address tokenB) external override view returns (address) {
        if (tokenA == busd && tokenB == bnb) {
            return bnbBusdPair;
        }
        if (tokenA == bnb && tokenB == btc) {
            return btcBnbPair;
        }
        revert("Invalid tokens");
    }
}
