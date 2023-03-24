// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IMintable {
    //是否铸造者
    function isMinter(address _account) external returns (bool);
    //设置铸造者
    function setMinter(address _minter, bool _isActive) external;
    //铸造
    function mint(address _account, uint256 _amount) external;
    //销毁
    function burn(address _account, uint256 _amount) external;
}
