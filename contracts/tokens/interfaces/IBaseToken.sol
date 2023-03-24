// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IBaseToken {
    //查询总抵押量
    function totalStaked() external view returns (uint256);
    //查询指定账户抵押的数量；
    function stakedBalance(address _account) external view returns (uint256);
    //移除指定账户的管理员权限
    function removeAdmin(address _account) external;
    //设置是否处于私有转账模式
    function setInPrivateTransferMode(bool _inPrivateTransferMode) external;
    //从指定账户提取一定数量的代币
    function withdrawToken(address _token, address _account, uint256 _amount) external;
}
