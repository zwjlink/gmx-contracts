//SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IPancakeFactory {
    //获取交易对
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}
