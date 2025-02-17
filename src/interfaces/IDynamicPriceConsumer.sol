// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

interface IDynamicPriceConsumer {
    /**
     * @notice Registers a price feed for a given token address.
     * @param _token The address of the token to register the price feed for.
     * @param _priceFeed The address of the price feed contract.
     */
    function registerPriceFeed(address _token, address _priceFeed) external;

    /**
     * @notice Fetches the price feed for a given token address.
     * @param _token The address of the token to fetch the price feed for.
     * @return The AggregatorV3Interface instance for the token.
     */
    function fetchPriceFeed(
        address _token
    ) external view returns (AggregatorV3Interface);

    /**
     * @notice Fetches the price for a given token address.
     * @param _token The address of the token to fetch the price for.
     * @return price The price of the token.
     */
    function fetchPrice(address _token) external view returns (int256 price);
}
