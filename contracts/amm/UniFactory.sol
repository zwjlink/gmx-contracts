// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

contract UniFactory {
    //交易对映射，三层
    //第一层：address，tokenA
    //第二层：address，tokenB
    //第三层：交易对费率,交易对地址
    mapping(address => mapping(address => mapping(uint24 => address))) public getPool;
}
