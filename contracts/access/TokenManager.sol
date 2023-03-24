//SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

//如果以后升级8.0之后的版本，不需要再使用safemath，但是要注意某些变了和函数名是否冲突
import "../libraries/math/SafeMath.sol"; //安全数学运算
import "../libraries/token/IERC20.sol"; //ERC20接口
import "../libraries/token/ERC721/IERC721.sol"; //ERC721接口
import "../libraries/utils/ReentrancyGuard.sol"; //防止重入攻击

import "../peripherals/interfaces/ITimelock.sol"; //定时锁定合约接口

//合约管理器
contract TokenManager is ReentrancyGuard {
    using SafeMath for uint256;

    bool public isInitialized; //是否初始化

    uint256 public actionsNonce; //操作序号
    uint256 public minAuthorizations; //最小授权数

    address public admin; //管理员地址

    address[] public signers; //签名者地址列表
    mapping (address => bool) public isSigner; //签名者地址列表
    mapping (bytes32 => bool) public pendingActions; //待处理操作列表
    mapping (address => mapping (bytes32 => bool)) public signedActions; //已签名操作列表

    event SignalApprove(address token, address spender, uint256 amount, bytes32 action, uint256 nonce);
    event SignalApproveNFT(address token, address spender, uint256 tokenId, bytes32 action, uint256 nonce);
    event SignalApproveNFTs(address token, address spender, uint256[] tokenIds, bytes32 action, uint256 nonce);
    event SignalSetAdmin(address target, address admin, bytes32 action, uint256 nonce);
    event SignalSetGov(address timelock, address target, address gov, bytes32 action, uint256 nonce);
    event SignalPendingAction(bytes32 action, uint256 nonce);
    event SignAction(bytes32 action, uint256 nonce);
    event ClearAction(bytes32 action, uint256 nonce);

    //构造函数，初始化管理员地址和最小授权数
    constructor(uint256 _minAuthorizations) public {
        admin = msg.sender;
        minAuthorizations = _minAuthorizations;
    }

    //修饰器：只有管理员才能调用
    modifier onlyAdmin() {
        require(msg.sender == admin, "TokenManager: forbidden");
        _;
    }

    //修饰器：只有签名者才能调用
    modifier onlySigner() {
        require(isSigner[msg.sender], "TokenManager: forbidden");
        _;
    }

    //初始化合约，这里是虚函数，可以被子合约重写，管理员可以使用
    function initialize(address[] memory _signers) public virtual onlyAdmin {
        require(!isInitialized, "TokenManager: already initialized"); //检查是否被初始化过，目的是只允许初始化一次
        isInitialized = true;

        signers = _signers; //签名者列表
        for (uint256 i = 0; i < _signers.length; i++) {
            address signer = _signers[i];
            isSigner[signer] = true; //签名者地址列表,标识为true
        }
    }

    //签名者列表的长度
    function signersLength() public view returns (uint256) {
        return signers.length;
    }

    //管理员发起一个多人签名的approve授权操作
    //params _token:代币地址
    //params _spender:授权地址
    //params _amount:授权数量
    function signalApprove(address _token, address _spender, uint256 _amount) external nonReentrant onlyAdmin {
        actionsNonce++; //操作序号+1
        uint256 nonce = actionsNonce; //操作序号
        //用一个hash值作为这个事件的唯一标识
        bytes32 action = keccak256(abi.encodePacked("approve", _token, _spender, _amount, nonce));
        //将这个事件的唯一标识添加到待处理操作列表中
        _setPendingAction(action, nonce);
        //触发事件log
        emit SignalApprove(_token, _spender, _amount, action, nonce);
    }

    //签名者授权操作
    //params _token:代币地址
    //params _spender:授权地址
    //params _amount:授权数量
    //params _nonce:操作序号
    function signApprove(address _token, address _spender, uint256 _amount, uint256 _nonce) external nonReentrant onlySigner {
        //获取到key
        bytes32 action = keccak256(abi.encodePacked("approve", _token, _spender, _amount, _nonce));
       //检查这个操作是否已经被签名过了
        _validateAction(action);
        require(!signedActions[msg.sender][action], "TokenManager: already signed");
        //将这个操作的签名者添加到已签名操作列表中
        signedActions[msg.sender][action] = true;
        emit SignAction(action, _nonce);
    }

    //管理员执行授权操作
    //params _token:代币地址
    //params _spender:授权地址
    //params _amount:授权数量
    //params _nonce:操作序号
    function approve(address _token, address _spender, uint256 _amount, uint256 _nonce) external nonReentrant onlyAdmin {
       //获取到key
        bytes32 action = keccak256(abi.encodePacked("approve", _token, _spender, _amount, _nonce));
        //检查这个操作是否已经被签名过了
        _validateAction(action);
        //检查是否满足最小签名的人员数量
        _validateAuthorization(action);
        //执行ERC20授权操作
        IERC20(_token).approve(_spender, _amount);
        _clearAction(action, _nonce);
    }

    //管理员发起多人签名的NFT授权操作
    function signalApproveNFT(address _token, address _spender, uint256 _tokenId) external nonReentrant onlyAdmin {
        actionsNonce++; //操作序号+1
        uint256 nonce = actionsNonce; //操作序号
        //用一个hash值作为这个事件的唯一标识
        bytes32 action = keccak256(abi.encodePacked("approveNFT", _token, _spender, _tokenId, nonce));
        //将这个事件的唯一标识添加到待处理操作列表中
        _setPendingAction(action, nonce);
        emit SignalApproveNFT(_token, _spender, _tokenId, action, nonce);
    }

    //签名者签名NFT授权操作
    function signApproveNFT(address _token, address _spender, uint256 _tokenId, uint256 _nonce) external nonReentrant onlySigner {
        //获取到key
        bytes32 action = keccak256(abi.encodePacked("approveNFT", _token, _spender, _tokenId, _nonce));
        //检查这个操作是否已经被签名过了
        _validateAction(action);

        require(!signedActions[msg.sender][action], "TokenManager: already signed");
        //将这个操作的签名者添加到已签名操作列表中
        signedActions[msg.sender][action] = true;
        emit SignAction(action, _nonce);
    }

    //管理员执行NFT授权操作
    function approveNFT(address _token, address _spender, uint256 _tokenId, uint256 _nonce) external nonReentrant onlyAdmin {
       //获取到key
        bytes32 action = keccak256(abi.encodePacked("approveNFT", _token, _spender, _tokenId, _nonce));
        //检查这个操作是否已经被签名过了
        _validateAction(action);
        //检查是否满足最小签名的人员数量
        _validateAuthorization(action);
        //执行ERC721授权操作
        IERC721(_token).approve(_spender, _tokenId);
        //清除这个操作
        _clearAction(action, _nonce);
    }

    //管理员发起多人签名的NFT批量授权操作
    function signalApproveNFTs(address _token, address _spender, uint256[] memory _tokenIds) external nonReentrant onlyAdmin {
        actionsNonce++; //操作序号+1
        uint256 nonce = actionsNonce; //操作序号
        bytes32 action = keccak256(abi.encodePacked("approveNFTs", _token, _spender, _tokenIds, nonce));
        //将这个事件的唯一标识添加到待处理操作列表中
        _setPendingAction(action, nonce);
        emit SignalApproveNFTs(_token, _spender, _tokenIds, action, nonce);
    }

    //签名者签名NFT批量授权操作
    function signApproveNFTs(address _token, address _spender, uint256[] memory _tokenIds, uint256 _nonce) external nonReentrant onlySigner {
        bytes32 action = keccak256(abi.encodePacked("approveNFTs", _token, _spender, _tokenIds, _nonce));
        _validateAction(action);
        require(!signedActions[msg.sender][action], "TokenManager: already signed");
        signedActions[msg.sender][action] = true;
        emit SignAction(action, _nonce);
    }

    //管理员执行批量NFT授权
    function approveNFTs(address _token, address _spender, uint256[] memory _tokenIds, uint256 _nonce) external nonReentrant onlyAdmin {
        bytes32 action = keccak256(abi.encodePacked("approveNFTs", _token, _spender, _tokenIds, _nonce));
        _validateAction(action);
        _validateAuthorization(action);

        //循环这些ID，多个授权
        for (uint256 i = 0 ; i < _tokenIds.length; i++) {
            IERC721(_token).approve(_spender, _tokenIds[i]);
        }
        _clearAction(action, _nonce);
    }

    //接收批量的NFT
    function receiveNFTs(address _token, address _sender, uint256[] memory _tokenIds) external nonReentrant onlyAdmin {
        for (uint256 i = 0 ; i < _tokenIds.length; i++) {
            IERC721(_token).transferFrom(_sender, address(this), _tokenIds[i]);
        }
    }

    //签名者发起一个设置管理员的请求
    function signalSetAdmin(address _target, address _admin) external nonReentrant onlySigner {
        actionsNonce++;
        uint256 nonce = actionsNonce;
        bytes32 action = keccak256(abi.encodePacked("setAdmin", _target, _admin, nonce));
        _setPendingAction(action, nonce);
        signedActions[msg.sender][action] = true;
        emit SignalSetAdmin(_target, _admin, action, nonce);
    }

    //签名设置管理员的请求
    function signSetAdmin(address _target, address _admin, uint256 _nonce) external nonReentrant onlySigner {
        bytes32 action = keccak256(abi.encodePacked("setAdmin", _target, _admin, _nonce));
        _validateAction(action);
        require(!signedActions[msg.sender][action], "TokenManager: already signed");
        signedActions[msg.sender][action] = true;
        emit SignAction(action, _nonce);
    }

    //设置管理员
    function setAdmin(address _target, address _admin, uint256 _nonce) external nonReentrant onlySigner {
        bytes32 action = keccak256(abi.encodePacked("setAdmin", _target, _admin, _nonce));
        _validateAction(action);
        _validateAuthorization(action);
        //时间锁设置管理员
        ITimelock(_target).setAdmin(_admin);
        _clearAction(action, _nonce);
    }

    //管理员发起一个设置治理合约地址的操作（Governable.sol）
    //@@param _timelock 时间锁合约地址
    //@param _target 目标合约地址
    //@param _gov 治理合约地址
    function signalSetGov(address _timelock, address _target, address _gov) external nonReentrant onlyAdmin {
        actionsNonce++;
        uint256 nonce = actionsNonce;
        bytes32 action = keccak256(abi.encodePacked("signalSetGov", _timelock, _target, _gov, nonce));
        _setPendingAction(action, nonce);
        signedActions[msg.sender][action] = true;
        emit SignalSetGov(_timelock, _target, _gov, action, nonce);
    }

    //签名者发起签名操作
    function signSetGov(address _timelock, address _target, address _gov, uint256 _nonce) external nonReentrant onlySigner {
        bytes32 action = keccak256(abi.encodePacked("signalSetGov", _timelock, _target, _gov, _nonce));
        _validateAction(action);
        require(!signedActions[msg.sender][action], "TokenManager: already signed");
        signedActions[msg.sender][action] = true;
        emit SignAction(action, _nonce);
    }

    //管理员设置治理合约地址
    function setGov(address _timelock, address _target, address _gov, uint256 _nonce) external nonReentrant onlyAdmin {
        bytes32 action = keccak256(abi.encodePacked("signalSetGov", _timelock, _target, _gov, _nonce));
        _validateAction(action);
        _validateAuthorization(action);
        //时间锁操作设置治理合约地址
        ITimelock(_timelock).signalSetGov(_target, _gov);
        _clearAction(action, _nonce);
    }

    //设置待操作的事件
    function _setPendingAction(bytes32 _action, uint256 _nonce) private {
        pendingActions[_action] = true;
        emit SignalPendingAction(_action, _nonce);
    }

    //验证待操作的事件
    function _validateAction(bytes32 _action) private view {
        require(pendingActions[_action], "TokenManager: action not signalled");
    }

    //验证签名是否达到满足大于等于minAuthorizations
    function _validateAuthorization(bytes32 _action) private view {
        uint256 count = 0;
        for (uint256 i = 0; i < signers.length; i++) {
            address signer = signers[i];
            if (signedActions[signer][_action]) {
                count++;
            }
        }

        if (count == 0) {
            revert("TokenManager: action not authorized");
        }
        require(count >= minAuthorizations, "TokenManager: insufficient authorization");
    }

    //清除待操作的事件
    function _clearAction(bytes32 _action, uint256 _nonce) private {
        require(pendingActions[_action], "TokenManager: invalid _action");
        delete pendingActions[_action];
        emit ClearAction(_action, _nonce);
    }
}
