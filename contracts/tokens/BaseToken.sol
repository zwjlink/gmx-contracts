// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../libraries/math/SafeMath.sol";
import "../libraries/token/IERC20.sol";
import "../libraries/token/SafeERC20.sol";

import "./interfaces/IYieldTracker.sol";
import "./interfaces/IBaseToken.sol";

contract BaseToken is IERC20, IBaseToken {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public override totalSupply; //总量
    uint256 public nonStakingSupply; //非抵押总量

    address public gov; //治理地址

    mapping (address => uint256) public balances; //账户地址对应的余额
    mapping (address => mapping (address => uint256)) public allowances; //账户地址对应的授权额度

    address[] public yieldTrackers; //地址数组，存储收益追踪器
    mapping (address => bool) public nonStakingAccounts;
    mapping (address => bool) public admins;

    bool public inPrivateTransferMode; //是否处于私有转账模式（只允许白名单用户使用）
    mapping (address => bool) public isHandler; //白名单用户

    //修饰器：是否治理地址
    modifier onlyGov() {
        require(msg.sender == gov, "BaseToken: forbidden");
        _;
    }

    //修饰器：是否管理员
    modifier onlyAdmin() {
        require(admins[msg.sender], "BaseToken: forbidden");
        _;
    }

    //构造函数：
    constructor(string memory _name, string memory _symbol, uint256 _initialSupply) public {
        name = _name; //币种名字
        symbol = _symbol; //币种单位
        gov = msg.sender; //治理地址
        _mint(msg.sender, _initialSupply); //给合约创建者发行初始总量
    }

    //设置治理地址
    function setGov(address _gov) external onlyGov {
        gov = _gov;
    }

    //更改币种名字和单位
    function setInfo(string memory _name, string memory _symbol) external onlyGov {
        name = _name;
        symbol = _symbol;
    }

    //设置存储收益追踪器的地址数组(farm合约产生？)
    function setYieldTrackers(address[] memory _yieldTrackers) external onlyGov {
        yieldTrackers = _yieldTrackers;
    }

    //添加管理员
    function addAdmin(address _account) external onlyGov {
        admins[_account] = true;
    }

    //移除管理员
    function removeAdmin(address _account) external override onlyGov {
        admins[_account] = false;
    }

    // to help users who accidentally send their tokens to this contract
    //转移代币，预防用户将代币发送到合约地址
    function withdrawToken(address _token, address _account, uint256 _amount) external override onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    //设置私人转账模式
    function setInPrivateTransferMode(bool _inPrivateTransferMode) external override onlyGov {
        inPrivateTransferMode = _inPrivateTransferMode;
    }

    //激活使用转账
    function setHandler(address _handler, bool _isActive) external onlyGov {
        isHandler[_handler] = _isActive;
    }

    //管理员添加非抵押账户，也就是让这个地址持有的代币不参与质押和挖矿，但仍然可以享受奖励
    function addNonStakingAccount(address _account) external onlyAdmin {
        //判断账户是否已经被添加
        require(!nonStakingAccounts[_account], "BaseToken: _account already marked");
        //更新收益
        _updateRewards(_account);
        //设置账户为非抵押账户
        nonStakingAccounts[_account] = true;
        //这个地址的代币数量加入到非质押代币总量 nonStakingSupply 中，以便后续计算奖励。
        nonStakingSupply = nonStakingSupply.add(balances[_account]);
    }

    //管理员移除非抵押账户
    function removeNonStakingAccount(address _account) external onlyAdmin {
        require(nonStakingAccounts[_account], "BaseToken: _account not marked");
        //更新收益
        _updateRewards(_account);
        //设置账户为抵押账户
        nonStakingAccounts[_account] = false;
        //这个地址的代币数量从非质押代币总量 nonStakingSupply 中减去，以便后续计算奖励。
        nonStakingSupply = nonStakingSupply.sub(balances[_account]);
    }

    //管理员一次性从收益追踪器中领取指定账户的收益给到_receiver地址
    function recoverClaim(address _account, address _receiver) external onlyAdmin {
        for (uint256 i = 0; i < yieldTrackers.length; i++) {
            address yieldTracker = yieldTrackers[i];
            IYieldTracker(yieldTracker).claim(_account, _receiver);
        }
    }

    //用户领取其在所有收益跟踪器中所赚取的奖励
    function claim(address _receiver) external {
        for (uint256 i = 0; i < yieldTrackers.length; i++) {
            address yieldTracker = yieldTrackers[i];
            IYieldTracker(yieldTracker).claim(msg.sender, _receiver);
        }
    }

    //所有已抵押代币的总量
    function totalStaked() external view override returns (uint256) {
        return totalSupply.sub(nonStakingSupply);
    }

    //获取账户地址对应的余额
    function balanceOf(address _account) external view override returns (uint256) {
        return balances[_account];
    }

    //获取指定地址的可抵押代币数量
    function stakedBalance(address _account) external view override returns (uint256) {
        if (nonStakingAccounts[_account]) {
            //如果是非抵押账户，返回0
            return 0;
        }
        return balances[_account];
    }

    //发送
    function transfer(address _recipient, uint256 _amount) external override returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    //查询可以转移的数量
    function allowance(address _owner, address _spender) external view override returns (uint256) {
        return allowances[_owner][_spender];
    }

    //授权
    function approve(address _spender, uint256 _amount) external override returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    //指定地址转移，注意授权
    function transferFrom(address _sender, address _recipient, uint256 _amount) external override returns (bool) {
        if (isHandler[msg.sender]) {
            _transfer(_sender, _recipient, _amount);
            return true;
        }
        uint256 nextAllowance = allowances[_sender][msg.sender].sub(_amount, "BaseToken: transfer amount exceeds allowance");
        _approve(_sender, msg.sender, nextAllowance);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    //给指定地址铸造代币
    function _mint(address _account, uint256 _amount) internal {
        require(_account != address(0), "BaseToken: mint to the zero address");

        //更新收益
        _updateRewards(_account);

        //增加代币总量
        totalSupply = totalSupply.add(_amount);
        //增加账户地址对应的代币数量
        balances[_account] = balances[_account].add(_amount);
        //如果是非抵押账户，增加非抵押代币总量
        if (nonStakingAccounts[_account]) {
            nonStakingSupply = nonStakingSupply.add(_amount);
        }
        emit Transfer(address(0), _account, _amount);
    }

    //给指定地址销毁代币
    function _burn(address _account, uint256 _amount) internal {
        require(_account != address(0), "BaseToken: burn from the zero address");

        _updateRewards(_account);

        balances[_account] = balances[_account].sub(_amount, "BaseToken: burn amount exceeds balance");
        totalSupply = totalSupply.sub(_amount);

        if (nonStakingAccounts[_account]) {
            nonStakingSupply = nonStakingSupply.sub(_amount);
        }

        emit Transfer(_account, address(0), _amount);
    }

    //交易发送
    function _transfer(address _sender, address _recipient, uint256 _amount) private {
        require(_sender != address(0), "BaseToken: transfer from the zero address");
        require(_recipient != address(0), "BaseToken: transfer to the zero address");

        if (inPrivateTransferMode) {
            require(isHandler[msg.sender], "BaseToken: msg.sender not whitelisted");
        }
        //更新双方收益
        _updateRewards(_sender);
        _updateRewards(_recipient);


        //余额更改
        balances[_sender] = balances[_sender].sub(_amount, "BaseToken: transfer amount exceeds balance");
        balances[_recipient] = balances[_recipient].add(_amount);

        //如果是非抵押账户，减少非抵押代币总量
        if (nonStakingAccounts[_sender]) {
            nonStakingSupply = nonStakingSupply.sub(_amount);
        }
        //如果是非抵押账户，增加非抵押代币总量
        if (nonStakingAccounts[_recipient]) {
            nonStakingSupply = nonStakingSupply.add(_amount);
        }

        emit Transfer(_sender, _recipient,_amount);
    }

    //授权
    function _approve(address _owner, address _spender, uint256 _amount) private {
        require(_owner != address(0), "BaseToken: approve from the zero address");
        require(_spender != address(0), "BaseToken: approve to the zero address");

        allowances[_owner][_spender] = _amount;

        emit Approval(_owner, _spender, _amount);
    }

    //更新收益
    function _updateRewards(address _account) private {
        for (uint256 i = 0; i < yieldTrackers.length; i++) {
            address yieldTracker = yieldTrackers[i];
            IYieldTracker(yieldTracker).updateRewards(_account);
        }
    }
}
