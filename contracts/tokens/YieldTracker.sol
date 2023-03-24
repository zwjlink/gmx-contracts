//SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../libraries/math/SafeMath.sol";
import "../libraries/token/IERC20.sol";
import "../libraries/token/SafeERC20.sol";
import "../libraries/utils/ReentrancyGuard.sol";

import "./interfaces/IDistributor.sol";
import "./interfaces/IYieldTracker.sol";
import "./interfaces/IYieldToken.sol";

//跟踪用户yieldToken的奖励，记录累计的奖励，可领取的奖励和前一个累积奖励
// code adapated from https://github.com/trusttoken/smart-contracts/blob/master/contracts/truefi/TrueFarm.sol
contract YieldTracker is IYieldTracker, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public constant PRECISION = 1e30; //精度值用于计算累积奖励（先乘再除以，减小误差）

    address public gov; //治理地址
    address public yieldToken; //token地址
    address public distributor; //分发器地址，处理奖励的分配和发送（updateRewards，claim）

    uint256 public cumulativeRewardPerToken; //累积奖励
    mapping (address => uint256) public claimableReward; //可领取的奖励
    mapping (address => uint256) public previousCumulatedRewardPerToken; //前一个累积奖励（帮助计算可领取的奖励）

    //log
    event Claim(address receiver, uint256 amount);

    modifier onlyGov() {
        require(msg.sender == gov, "YieldTracker: forbidden");
        _;
    }

    //构造器：设置治理地址和token地址
    constructor(address _yieldToken) public {
        gov = msg.sender;
        yieldToken = _yieldToken;
    }


    function setGov(address _gov) external onlyGov {
        gov = _gov;
    }


    //设置分配器地址
    function setDistributor(address _distributor) external onlyGov {
        distributor = _distributor;
    }

    // to help users who accidentally send their tokens to this contract
    //提取代币，避免用户将代币发送到此合约
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    //
    function claim(address _account, address _receiver) external override returns (uint256) {
        //yieldToken合约地址
        require(msg.sender == yieldToken, "YieldTracker: forbidden");
        //更新账户奖励
        updateRewards(_account);
        //可领取的奖励
        uint256 tokenAmount = claimableReward[_account];
        //可领取的奖励清零
        claimableReward[_account] = 0;
        //获取代币奖励的地址
        address rewardToken = IDistributor(distributor).getRewardToken(address(this));
        //发送奖励
        IERC20(rewardToken).safeTransfer(_receiver, tokenAmount);
        emit Claim(_account, tokenAmount);

        return tokenAmount;
    }

    function getTokensPerInterval() external override view returns (uint256) {
        return IDistributor(distributor).tokensPerInterval(address(this));
    }

    function claimable(address _account) external override view returns (uint256) {
        //获取质押余额
        uint256 stakedBalance = IYieldToken(yieldToken).stakedBalance(_account);
        if (stakedBalance == 0) {
            //返回账户之前已经领取的奖励数量
            return claimableReward[_account];
        }
        //获取分发器地址
        uint256 pendingRewards = IDistributor(distributor).getDistributionAmount(address(this)).mul(PRECISION);
        //获取总质押量
        uint256 totalStaked = IYieldToken(yieldToken).totalStaked();
       //计算下一个累积奖励
        uint256 nextCumulativeRewardPerToken = cumulativeRewardPerToken.add(pendingRewards.div(totalStaked));
        //返回账户之前已经领取的奖励数量+账户质押余额*（下一个累积奖励-前一个累积奖励）/精度值
        return claimableReward[_account].add(
            stakedBalance.mul(nextCumulativeRewardPerToken.sub(previousCumulatedRewardPerToken[_account])).div(PRECISION));
    }

    //更新账户奖励
    function updateRewards(address _account) public override nonReentrant {
        uint256 blockReward; //区块奖励

        if (distributor != address(0)) {
            blockReward = IDistributor(distributor).distribute();
        }

        //累积的奖励
        uint256 _cumulativeRewardPerToken = cumulativeRewardPerToken;
        //获取总质押量
        uint256 totalStaked = IYieldToken(yieldToken).totalStaked();
        // only update cumulativeRewardPerToken when there are stakers, i.e. when totalStaked > 0
        // if blockReward == 0, then there will be no change to cumulativeRewardPerToken
        if (totalStaked > 0 && blockReward > 0) {
            //累积奖励=累积奖励+（区块奖励*精度值/总质押量）
            _cumulativeRewardPerToken = _cumulativeRewardPerToken.add(blockReward.mul(PRECISION).div(totalStaked));
            //更新累积奖励
            cumulativeRewardPerToken = _cumulativeRewardPerToken;
        }

        // cumulativeRewardPerToken can only increase
        // so if cumulativeRewardPerToken is zero, it means there are no rewards yet
        if (_cumulativeRewardPerToken == 0) {
            return;
        }

        if (_account != address(0)) {
            //函数首先获取 _account 的抵押数量 stakedBalance，
            //然后获取 _account 的前一个累积奖励 _previousCumulatedReward，
            //最后计算出 _account 的可领取奖励 _claimableReward
            uint256 stakedBalance = IYieldToken(yieldToken).stakedBalance(_account);
            uint256 _previousCumulatedReward = previousCumulatedRewardPerToken[_account];
            //可领取的奖励=之前已经领取的奖励+账户质押余额*（累积奖励-前一个累积奖励）/精度值
            uint256 _claimableReward = claimableReward[_account].add(
                stakedBalance.mul(_cumulativeRewardPerToken.sub(_previousCumulatedReward)).div(PRECISION)
            );
            //更新账户可领取的奖励
            claimableReward[_account] = _claimableReward;
            //更新账户前一个累积奖励
            previousCumulatedRewardPerToken[_account] = _cumulativeRewardPerToken;
        }
    }
}
