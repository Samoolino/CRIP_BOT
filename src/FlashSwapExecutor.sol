// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from './interfaces/IERC20.sol';
import {IV2Pair} from './interfaces/IV2Pair.sol';
import {IV2Router02} from './interfaces/IV2Router02.sol';

/// @notice Atomic V2-style flash-swap executor for a pre-approved deployment.
/// @dev This is intentionally route-constrained in v1: one approved router and
///      one two-token path. The off-chain bot performs opportunity discovery.
contract FlashSwapExecutor {
    error NotOwner();
    error NotPair();
    error PairAlreadyConfigured();
    error InvalidPair();
    error InvalidAsset();
    error InvalidRouter();
    error InvalidPath();
    error InvalidAmount();
    error InsufficientProfit(uint256 actual, uint256 minimum);
    error TransferFailed();
    error ApprovalFailed();
    error ExecutionActive();

    address public immutable owner;
    address public immutable factory;
    address public immutable router;

    address public configuredPair;
    bool private executing;

    event PairConfigured(address indexed pair, address indexed tokenBorrow, address indexed tokenIntermediate);
    event ArbitrageExecuted(
        address indexed pair,
        address indexed tokenBorrow,
        uint256 borrowed,
        uint256 repayment,
        uint256 profit
    );
    event ProfitWithdrawn(address indexed token, uint256 amount, address indexed recipient);

    constructor(address factory_, address router_) {
        if (factory_ == address(0) || router_ == address(0)) revert InvalidPair();
        owner = msg.sender;
        factory = factory_;
        router = router_;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @notice Registers a pair after validating its factory and token addresses.
    /// @dev Pair discovery remains deployment-specific and is deliberately not
    ///      based on a copied universal init-code hash.
    function configurePair(address pair) external onlyOwner {
        if (configuredPair != address(0)) revert PairAlreadyConfigured();
        if (pair == address(0)) revert InvalidPair();
        if (IV2Pair(pair).factory() != factory) revert InvalidPair();

        address token0 = IV2Pair(pair).token0();
        address token1 = IV2Pair(pair).token1();
        if (token0 == address(0) || token1 == address(0) || token0 == token1) revert InvalidPair();

        configuredPair = pair;
        emit PairConfigured(pair, token0, token1);
    }

    /// @notice Initiates a flash swap. The borrowed side is determined by token0/token1.
    /// @param borrowToken Token borrowed from the pair.
    /// @param amount Borrow amount.
    /// @param path Exactly [borrowToken, intermediateToken, borrowToken] is required.
    /// @param minProfit Minimum surplus after pair repayment.
    function execute(
        address borrowToken,
        uint256 amount,
        address[] calldata path,
        uint256 minProfit
    ) external onlyOwner {
        if (executing) revert ExecutionActive();
        address pair = configuredPair;
        if (pair == address(0) || amount == 0) revert InvalidAmount();
        if (path.length != 3 || path[0] != borrowToken || path[2] != borrowToken) revert InvalidPath();

        address token0 = IV2Pair(pair).token0();
        address token1 = IV2Pair(pair).token1();
        if (borrowToken != token0 && borrowToken != token1) revert InvalidAsset();
        if (path[1] == address(0) || path[1] == borrowToken) revert InvalidPath();

        uint256 amount0Out = borrowToken == token0 ? amount : 0;
        uint256 amount1Out = borrowToken == token1 ? amount : 0;
        bytes memory data = abi.encode(borrowToken, amount, path, minProfit);

        executing = true;
        IV2Pair(pair).swap(amount0Out, amount1Out, address(this), data);
        executing = false;
    }

    /// @notice Uniswap-V2-compatible flash-swap callback.
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        if (msg.sender != configuredPair || sender != address(this)) revert NotPair();
        if (!executing) revert ExecutionActive();
        if ((amount0 == 0) == (amount1 == 0)) revert InvalidAmount();

        (address borrowToken, uint256 borrowed, address[] memory path, uint256 minProfit) =
            abi.decode(data, (address, uint256, address[], uint256));

        address token0 = IV2Pair(msg.sender).token0();
        address token1 = IV2Pair(msg.sender).token1();
        address expectedBorrow = amount0 > 0 ? token0 : token1;
        if (borrowToken != expectedBorrow || borrowed != (amount0 > 0 ? amount0 : amount1)) revert InvalidAsset();
        if (path.length != 3 || path[0] != borrowToken || path[2] != borrowToken) revert InvalidPath();

        uint256 intermediateBefore = IERC20(path[1]).balanceOf(address(this));
        _approve(path[0], router, borrowed);
        IV2Router02(router).swapExactTokensForTokens(
            borrowed,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 borrowedBalance = IERC20(borrowToken).balanceOf(address(this));
        uint256 repayment = _repayment(borrowed, amount0 > 0 ? token1 : token0);
        uint256 intermediateAfter = IERC20(path[1]).balanceOf(address(this));
        if (intermediateAfter < intermediateBefore) revert InvalidAmount();
        if (borrowedBalance < repayment + minProfit) {
            revert InsufficientProfit(borrowedBalance - (borrowedBalance < repayment ? borrowedBalance : repayment), minProfit);
        }

        _transfer(borrowToken, msg.sender, repayment);
        uint256 profit = borrowedBalance - repayment;
        if (profit > 0) _transfer(borrowToken, owner, profit);
        emit ArbitrageExecuted(msg.sender, borrowToken, borrowed, repayment, profit);
    }

    /// @dev V2 repayment for a single-sided flash swap, derived from the opposite reserve.
    ///      amountIn = ceil(amountOut * 1000 * reserveIn / ((reserveOut-amountOut) * 997)).
    function _repayment(uint256 amountOut, address otherToken) internal view returns (uint256) {
        (uint112 reserve0, uint112 reserve1,) = IV2Pair(configuredPair).getReserves();
        address token0 = IV2Pair(configuredPair).token0();
        uint256 reserveOut = otherToken == token0 ? reserve0 : reserve1;
        uint256 reserveIn = otherToken == token0 ? reserve1 : reserve0;
        if (amountOut >= reserveOut) revert InvalidAmount();
        uint256 numerator = amountOut * 1000 * reserveIn;
        uint256 denominator = (reserveOut - amountOut) * 997;
        return numerator / denominator + 1;
    }

    function withdrawToken(address token, uint256 amount) external onlyOwner {
        _transfer(token, owner, amount);
        emit ProfitWithdrawn(token, amount, owner);
    }

    function _approve(address token, address spender, uint256 amount) internal {
        if (!IERC20(token).approve(spender, 0)) revert ApprovalFailed();
        if (!IERC20(token).approve(spender, amount)) revert ApprovalFailed();
    }

    function _transfer(address token, address to, uint256 amount) internal {
        if (!IERC20(token).transfer(to, amount)) revert TransferFailed();
    }
}
