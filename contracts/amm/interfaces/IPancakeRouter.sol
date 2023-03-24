// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IPancakeRouter {
    //添加流动性
    //tokenA和tokenB是交易对的两个token
    //amountADesired和amountBDesired是用户希望添加的tokenA和tokenB的数量
    //amountAMin和amountBMin是用户希望添加的tokenA和tokenB的最小数量
    //to是流动性代币的接收地址
    //deadline是截止时间

    //@@return amountA, amountB, liquidity
    //amountA和amountB是实际添加的tokenA和tokenB的数量
    //liquidity是流动性代币的数量
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
}
