//SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

//定义IAdmin接口
interface IAdmin {
    //设置管理员地址
    //external限制外部合约调用
    function setAdmin(address _admin) external;
}
