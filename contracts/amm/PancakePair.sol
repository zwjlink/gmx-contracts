// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./interfaces/IPancakePair.sol";

contract PancakePair is IPancakePair {
    //第一个资产的储备量
    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    //第二个资产的储备量
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
   // 上一次更新的时间戳
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves

    //设置储备量
    function setReserves(uint256 balance0, uint256 balance1) external {
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = uint32(block.timestamp);
    }

    //获取储备量以及最后一次更新的时间戳
    function getReserves() public override view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }
}
