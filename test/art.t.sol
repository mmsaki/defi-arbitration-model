// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./interface.sol";

// Contrasts
address constant uniV3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
address constant balancerVault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
address constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // weth
address constant dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI
address constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
address constant wbtc = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599; // WBTC
address constant usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
address constant ust = 0xa47c8bf37f92aBed4A126BDA807A7b7498661acD; // UST
address constant crv = 0xD533a949740bb3306d119CC777fa900bA034cd52; // crv
address constant glm = 0x7DD9c5Cba05E151C895FDe1CF355C9A1D5DA6429; // glm


contract ARB_Defi is Test {
    address user = makeAddr("the arbitrator");
    Arbitrator arbitrator;

    function setUp() public {
        vm.createSelectFork("mainnet");
        
        vm.label(weth, "weth");
        vm.label(dai, "dai");
        vm.label(usdc, "usdc");
        vm.label(wbtc, "wbtc");
        vm.label(usdt, "usdt");
        vm.label(ust, "ust");
        vm.label(crv, "crv");
    }

    function testPoC() public {
        console.log('Previous balance in WETH :', Interface(weth).balanceOf(user));
        console.log(block.timestamp);

        vm.startPrank(user);
        arbitrator = new Arbitrator();
        arbitrator.aribitrate();

        console.log('3. Final balance in WETH :', Interface(weth).balanceOf(user));
    }
}

contract Arbitrator {
    address txSender;

    address token_1 = weth;
    address token_2 = glm;
    uint24 fee_1 = 10000;  
    uint24 fee_2 = 3000; 
    uint24 fee_3 = 3000;


    function aribitrate() external {
        txSender = msg.sender;
        
        uint256 amount_1 = 1000000000000000;
        Interface(token_1).approve(uniV3Router, amount_1);
        Interface(token_2).approve(uniV3Router, type(uint256).max);

        address[] memory tokens = new address[](1);
        tokens[0] = token_1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount_1;
        Interface(balancerVault).flashLoan(
            address(this),
            tokens,
            amounts,
            ""
        );
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
    
        uint256 bal_1 = Interface(token_1).balanceOf(address(this));
        console.log("0. Received flashloan token_1", bal_1);

        /******** 1nd swap ***************/
        Interface.ExactInputSingleParams memory input = Interface.ExactInputSingleParams(
            token_1, // address tokenIn;
            token_2, // address tokenOut;
            fee_1, // uint24 fee;
            address(this), // address recipient;
            block.timestamp, // uint256 deadline;
            bal_1, // uint256 amountIn;
            0, // uint256 amountOutMinimum;
            0 // uint160 sqrtPriceLimitX96;
        );
        Interface(uniV3Router).exactInputSingle(input);
        uint bal_2 = Interface(token_2).balanceOf(address(this));
        console.log("1.1 Bought", token_2, bal_2);


        /******** 2nd swap ***************/
        input = Interface.ExactInputSingleParams(
            token_2, // address tokenIn;
            token_1, // address tokenOut;
            fee_2, // uint24 fee;
            address(this), // address recipient;
            block.timestamp, // uint256 deadline;
            bal_2, // uint256 amountIn;
            0, // uint256 amountOutMinimum;
            0 // uint160 sqrtPriceLimitX96;
        );
        Interface(uniV3Router).exactInputSingle(input);
        uint bal_3 = Interface(token_1).balanceOf(address(this));
        console.log("1.2 Sold", token_2, bal_3);

        console.log("2.0 WETH Balance", Interface(token_1).balanceOf(address(this)));
        Interface(token_1).transfer(balancerVault, amounts[0]);

        uint256 bal_remainder = Interface(token_1).balanceOf(address(this));

        console.log("2.2 Profit remainder", bal_remainder);
        Interface(token_1).transfer(txSender, bal_remainder);
    }

    receive() external payable {}
}

interface Interface is IERC20 {
    // balancerVault
    function flashLoan(
        address recipient,
        address[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;

    // WETH
    function withdraw(uint wad) external;

    // Uniswap V3: SwapRouter
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}