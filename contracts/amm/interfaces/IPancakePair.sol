// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0;

interface IPancakePair {
    //获取交易对的储备量和最后更新的时间戳
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}
