// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./BaseToken.sol";
import "./interfaces/IMintable.sol";

contract MintableBaseToken is BaseToken, IMintable {

    //是否铸造者
    mapping (address => bool) public override isMinter;

    constructor(string memory _name, string memory _symbol, uint256 _initialSupply) public BaseToken(_name, _symbol, _initialSupply) {
    }

    //修饰器：是否铸造者
    modifier onlyMinter() {
        require(isMinter[msg.sender], "MintableBaseToken: forbidden");
        _;
    }

    //设置铸造者
    function setMinter(address _minter, bool _isActive) external override onlyGov {
        isMinter[_minter] = _isActive;
    }

    //铸造
    function mint(address _account, uint256 _amount) external override onlyMinter {
        _mint(_account, _amount);
    }

    //销毁
    function burn(address _account, uint256 _amount) external override onlyMinter {
        _burn(_account, _amount);
    }
}
