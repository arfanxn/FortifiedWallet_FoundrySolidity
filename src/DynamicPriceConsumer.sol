// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IDynamicPriceConsumer} from "src/interfaces/IDynamicPriceConsumer.sol";

contract DynamicPriceConsumer is IDynamicPriceConsumer {
    error PriceFeedIsNotRegistered();

    mapping(address => AggregatorV3Interface) private priceFeeds;

    /**
     * @notice Registers a price feed for a given token address.
     * @param _token The address of the token to register the price feed for.
     * @param _priceFeed The address of the price feed contract.
     */
    function registerPriceFeed(address _token, address _priceFeed) public {
        priceFeeds[_token] = AggregatorV3Interface(_priceFeed);
    }

    /**
     * @notice Fetches the price feed for a given token address.
     * @param _token The address of the token to fetch the price feed for.
     * @return The AggregatorV3Interface instance for the token.
     * @dev Reverts if the token is a non-zero address and no price feed is registered.
     */
    function fetchPriceFeed(
        address _token
    ) public view returns (AggregatorV3Interface) {
        AggregatorV3Interface priceFeed = priceFeeds[_token];
        bool tokenIsETH = _token == address(0);
        bool priceFeedIsZero = address(priceFeed) == address(0);
        if (!tokenIsETH && priceFeedIsZero) {
            revert PriceFeedIsNotRegistered();
        }
        return priceFeed;
    }

    /**
     * @notice Fetches the price for a given token address.
     * @param _token The address of the token to fetch the price for.
     * @return price The price of the token.
     * @dev Reverts if the token is a non-zero address and no price feed is registered.
     */
    function fetchPrice(address _token) public view returns (int256 price) {
        AggregatorV3Interface priceFeed = fetchPriceFeed(_token);
        (, price, , , ) = priceFeed.latestRoundData();
        return price;
    }
}
