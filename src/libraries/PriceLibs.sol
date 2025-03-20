// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library PriceLibs {
    function getScaledPriceXAmount(
        address token,
        uint256 amount,
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        address Ether = address(0);
        bool isEther = token == Ether;
        uint8 tokenDecimals = isEther
            ? 18
            : IERC20Metadata(token).decimals();

        // Adjust decimals for calculation
        uint256 scaledPrice = getScaledPrice(priceFeed);
        uint256 scaledAmount = amount * (10 ** (18 - tokenDecimals)); // Scale to 18 decimals

        // Calculate USD value (amount * price)
        return (scaledAmount * scaledPrice) / 1e18; // Divide by 1e18 to normalize
    }

    function getScaledPrice(
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint8 priceFeedDecimals = priceFeed.decimals();

        // Adjust decimals for calculation
        uint256 scaledPrice = uint256(price) * (10 ** (18 - priceFeedDecimals)); // Scale to 18 decimals
        return scaledPrice;
    }
}
