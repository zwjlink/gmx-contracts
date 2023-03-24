// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

//治理合约
//该合约实现了一种简单的治理机制，使合约的创建者可以在后续的操作中将控制权交给其他人
contract Governable {
    address public gov;

    //构造函数，初始化合约创建者为管理员
    constructor() public {
        gov = msg.sender;
    }

    //修饰器：只有管理员才能调用
    modifier onlyGov() {
        require(msg.sender == gov, "Governable: forbidden");
        _;
    }

    //设置管理员地址
    function setGov(address _gov) external onlyGov {
        gov = _gov;
    }
}
