// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IYieldTracker {
    //从合约中提取
    // _account: 账户地址
    // _receiver: 接收地址
    function claim(address _account, address _receiver) external returns (uint256);
    //更新_account地址奖励
    function updateRewards(address _account) external;
    //用于查询每个时间间隔内可以领取的奖励数量
    function getTokensPerInterval() external view returns (uint256);
    //查询 _account 对应的地址可以领取的奖励数量
    function claimable(address _account) external view returns (uint256);
}
