// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IDealer.sol";
import "./IPerpetual.sol";

contract JOJOIntegration {

    IDealer public jojoDealerInterface;
    address public jojoDealer;
    address public owner;
    address public operator; // EOA operator for the smart contract
    address public degenDealer;

    address public primaryAsset;  // e.g., USDC
    address public secondaryAsset; // Optional e.g., JUSD if needed

    modifier onlyOwner() {
        require(msg.sender == owner, "JOJOIntegration: Not the owner");
        _;
    }

    constructor(address _jojoDealer, address _primaryAsset, address _secondaryAsset) {
        jojoDealer = _jojoDealer;
        owner = msg.sender; // Set the deployer as the owner
        primaryAsset = _primaryAsset;
        secondaryAsset = _secondaryAsset;
        jojoDealerInterface = IDealer(_jojoDealer);

    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "JOJOIntegration: New owner is the zero address");
        owner = newOwner;
    }

    // Dealer Functions
    function setOperator(address _operator, bool isValid) external onlyOwner {
        IDealer(jojoDealer).setOperator(_operator, isValid);
        operator = _operator;
    }

    function openTrade(
        address perp, // Perpetual market address
        int128 paperAmount, // Positive for long, negative for short
        int128 creditAmount, // Margin to allocate
        bytes32 info // Optional trade metadata
    ) external onlyOwner {
         // Construct the order
        Types.Order memory order = Types.Order({
            perp: perp,
            signer: operator, // Smart contract as the trader
            paperAmount: paperAmount,
            creditAmount: creditAmount,
            info: info
        });

        // Encode the order
        bytes memory encodedOrder = abi.encode(order);
        // Approve the trade
        IDealer(jojoDealer).approveTrade(operator, encodedOrder);
    }

    function closeTrade(
        address perp,
        int128 paperAmount, // Use the same amount as the open position but reversed
        bytes32 info
    ) external onlyOwner {
    // Reverse the order to close the position
        Types.Order memory order = Types.Order({
            perp: perp,
            signer: operator,
            paperAmount: -paperAmount, // Reverse the position
            creditAmount: 0, // No additional margin needed
            info: info
        });

        // Encode the order
        bytes memory encodedOrder = abi.encode(order);

        // Approve the trade
        IDealer(jojoDealer).approveTrade(operator, encodedOrder);
    }

    function deposit(
        uint256 primaryAmount,
        uint256 secondaryAmount
    ) external onlyOwner {

        IERC20(primaryAsset).approve(jojoDealer, primaryAmount);
        //IERC20(secondaryAsset).approve(jojoDealer, secondaryAmount);

        jojoDealerInterface.deposit(primaryAmount, secondaryAmount, address(this));
    }

    function requestWithdraw(
        address from,
        uint256 primaryAmount,
        uint256 secondaryAmount
    ) external onlyOwner {
        IDealer(jojoDealer).requestWithdraw(from, primaryAmount, secondaryAmount);
    }

    function executeWithdraw(
        address from,
        address to,
        bool isInternal,
        bytes memory param
    ) external onlyOwner {
        IDealer(jojoDealer).executeWithdraw(from, to, isInternal, param);
    }

    function fastWithdraw(
        address from,
        address to,
        uint256 primaryAmount,
        uint256 secondaryAmount,
        bool isInternal,
        bytes memory param
    ) external onlyOwner {
        IDealer(jojoDealer).fastWithdraw(from, to, primaryAmount, secondaryAmount, isInternal, param);
    }

    function approveTrade(address orderSender, bytes calldata tradeData)
        external
        onlyOwner
        returns (
            address[] memory traderList,
            int256[] memory paperChangeList,
            int256[] memory creditChangeList
        )
    {
        return IDealer(jojoDealer).approveTrade(orderSender, tradeData);
    }

    function isSafe(address trader) external view returns (bool) {
        return IDealer(jojoDealer).isSafe(trader);
    }

    function isAllSafe(address[] calldata traderList) external view returns (bool) {
        return IDealer(jojoDealer).isAllSafe(traderList);
    }

    function getFundingRate(address perp) external view returns (int256) {
        return IDealer(jojoDealer).getFundingRate(perp);
    }

    function updateFundingRate(address[] calldata perpList, int256[] calldata rateList)
        external
        onlyOwner
    {
        IDealer(jojoDealer).updateFundingRate(perpList, rateList);
    }

    function requestLiquidation(
        address executor,
        address liquidator,
        address liquidatedTrader,
        int256 requestPaperAmount
    )
        external
        onlyOwner
        returns (
            int256 liqtorPaperChange,
            int256 liqtorCreditChange,
            int256 liqedPaperChange,
            int256 liqedCreditChange
        )
    {
        return
            IDealer(jojoDealer).requestLiquidation(
                executor,
                liquidator,
                liquidatedTrader,
                requestPaperAmount
            );
    }

    function handleBadDebt(address liquidatedTrader) external onlyOwner {
        IDealer(jojoDealer).handleBadDebt(liquidatedTrader);
    }

    function openPosition(address trader) external onlyOwner {
        IDealer(jojoDealer).openPosition(trader);
    }

    function realizePnl(address trader, int256 pnl) external onlyOwner {
        IDealer(jojoDealer).realizePnl(trader, pnl);
    }

    function getRiskParams(address perp)
        external
        view
        returns (Types.RiskParams memory params)
    {
        return IDealer(jojoDealer).getRiskParams(perp);
    }

    function getAllRegisteredPerps() external view returns (address[] memory) {
        return IDealer(jojoDealer).getAllRegisteredPerps();
    }

    function getMarkPrice(address perp) external view returns (uint256) {
        return IDealer(jojoDealer).getMarkPrice(perp);
    }

    function getPositions(address trader) external view returns (address[] memory) {
        return IDealer(jojoDealer).getPositions(trader);
    }

    function getCreditOf(address trader)
        external
        view
        returns (
            int256 primaryCredit,
            uint256 secondaryCredit,
            uint256 pendingPrimaryWithdraw,
            uint256 pendingSecondaryWithdraw,
            uint256 executionTimestamp
        )
    {
        return IDealer(jojoDealer).getCreditOf(trader);
    }

    function getTraderRisk(address trader)
        external
        view
        returns (
            int256 netValue,
            uint256 exposure,
            uint256 initialMargin,
            uint256 maintenanceMargin
        )
    {
        return IDealer(jojoDealer).getTraderRisk(trader);
    }

    function getLiquidationPrice(address trader, address perp)
        external
        view
        returns (uint256 liquidationPrice)
    {
        return IDealer(jojoDealer).getLiquidationPrice(trader, perp);
    }

    function getLiquidationCost(
        address perp,
        address liquidatedTrader,
        int256 requestPaperAmount
    )
        external
        view
        returns (int256 liqtorPaperChange, int256 liqtorCreditChange)
    {
        return IDealer(jojoDealer).getLiquidationCost(perp, liquidatedTrader, requestPaperAmount);
    }

    function getOrderFilledAmount(bytes32 orderHash) external view returns (uint256 filledAmount) {
        return IDealer(jojoDealer).getOrderFilledAmount(orderHash);
    }

    function isOrderSenderValid(address orderSender) external view returns (bool) {
        return IDealer(jojoDealer).isOrderSenderValid(orderSender);
    }

    function isFastWithdrawalValid(address fastWithdrawOperator) external view returns (bool) {
        return IDealer(jojoDealer).isFastWithdrawalValid(fastWithdrawOperator);
    }

    function isOperatorValid(address client, address _operator) external view returns (bool) {
        return IDealer(jojoDealer).isOperatorValid(client, _operator);
    }

    function isCreditAllowed(address from, address spender)
        external
        view
        returns (uint256 primaryCreditAllowed, uint256 secondaryCreditAllowed)
    {
        return IDealer(jojoDealer).isCreditAllowed(from, spender);
    }

    // Perpetual Functions

    function getBalanceOf(address trader, address _perp)
        external
        view
        returns (int256 paper, int256 credit)
    {
        return IPerpetual(_perp).balanceOf(trader);
    }

    function trade(bytes calldata tradeData, address _perp) external onlyOwner {
        IPerpetual(_perp).trade(tradeData);
    }

    function liquidate(
        address liquidator,
        address liquidatedTrader,
        int256 requestPaper,
        int256 expectCredit,
        address _perp
    )
        external
        onlyOwner
        returns (int256 liqtorPaperChange, int256 liqtorCreditChange)
    {
        return
            IPerpetual(_perp).liquidate(
                liquidator,
                liquidatedTrader,
                requestPaper,
                expectCredit
            );
    }

    function getPerpetualFundingRate(address _perp) external view returns (int256) {
        return IPerpetual(_perp).getFundingRate();
    }

    function updatePerpetualFundingRate(int256 newFundingRate, address _perp) external onlyOwner {
        IPerpetual(_perp).updateFundingRate(newFundingRate);
    }

    
    receive() external payable {}
    
    fallback() external payable {}
}
