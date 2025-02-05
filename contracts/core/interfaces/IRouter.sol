// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IRouter {
    function addPlugin(address _plugin) external;
    //交易
    function pluginTransfer(address _token, address _account, address _receiver, uint256 _amount) external;
    //加仓
    function pluginIncreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _sizeDelta, bool _isLong) external;
    //减仓
    function pluginDecreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver) external returns (uint256);
    //交易兑换
    function swap(address[] memory _path, uint256 _amountIn, uint256 _minOut, address _receiver) external;
}
