// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Metadata} from "src/interfaces/IERC20Metadata.sol";
import {IDynamicPriceConsumer} from "../interfaces/IDynamicPriceConsumer.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library PriceUtils {
    /**
     * @notice Calculates the USD value of a given amount of a token.
     * @param token The address of the token.
     * @param amount The amount of the token to calculate the USD value for.
     * @param priceConsumer The IDynamicPriceConsumer instance to use to fetch the price feed.
     * @return usdValue The USD value of the token.
     */
    function getUsdValue(
        address token,
        uint256 amount,
        IDynamicPriceConsumer priceConsumer
    ) internal view returns (uint256 usdValue) {
        bool isEtherToken = token == address(0);
        uint8 tokenDecimals = isEtherToken
            ? 18
            : IERC20Metadata(token).decimals();

        AggregatorV3Interface priceFeed = priceConsumer.fetchPriceFeed(token);
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint8 priceFeedDecimals = priceFeed.decimals();

        // Adjust decimals for calculation
        uint256 adjustedPrice = uint256(price) *
            (10 ** (18 - priceFeedDecimals)); // Scale to 18 decimals
        uint256 adjustedAmount = amount * (10 ** (18 - tokenDecimals)); // Scale to 18 decimals

        // Calculate USD value (amount * price)
        usdValue = (adjustedAmount * adjustedPrice) / 1e18; // Divide by 1e18 to normalize
    }
}
