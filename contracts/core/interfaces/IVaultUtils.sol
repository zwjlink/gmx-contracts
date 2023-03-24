// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IVaultUtils {
    //更新资金费率
    function updateCumulativeFundingRate(address _collateralToken, address _indexToken) external returns (bool);
    //验证增加头寸
    function validateIncreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _sizeDelta, bool _isLong) external view;
    //验证减少头寸
    function validateDecreasePosition(address _account, address _collateralToken, address _indexToken, uint256 _collateralDelta, uint256 _sizeDelta, bool _isLong, address _receiver) external view;
    //验证清算
    function validateLiquidation(address _account, address _collateralToken, address _indexToken, bool _isLong, bool _raise) external view returns (uint256, uint256);

    function getEntryFundingRate(address _collateralToken, address _indexToken, bool _isLong) external view returns (uint256);
    //获取头寸费用
    function getPositionFee(address _account, address _collateralToken, address _indexToken, bool _isLong, uint256 _sizeDelta) external view returns (uint256);
    //获取资金费用
    function getFundingFee(address _account, address _collateralToken, address _indexToken, bool _isLong, uint256 _size, uint256 _entryFundingRate) external view returns (uint256);
    //获取购买usdg的费用基点
    function getBuyUsdgFeeBasisPoints(address _token, uint256 _usdgAmount) external view returns (uint256);
    //获取出售usdg的费用基点
    function getSellUsdgFeeBasisPoints(address _token, uint256 _usdgAmount) external view returns (uint256);
    //获取交换费用基点
    function getSwapFeeBasisPoints(address _tokenIn, address _tokenOut, uint256 _usdgAmount) external view returns (uint256);
    //获取usdg的费用基点
    function getFeeBasisPoints(address _token, uint256 _usdgDelta, uint256 _feeBasisPoints, uint256 _taxBasisPoints, bool _increment) external view returns (uint256);
}
