// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Errors} from "src/Errors.sol";

contract PriceFeedRegistry is Ownable, Errors {
    error PriceFeedDoesNotExist();

    mapping(address => AggregatorV3Interface) private s_priceFeeds;

    constructor() Ownable(msg.sender) {}

    function setPriceFeed(
        address _token,
        AggregatorV3Interface _priceFeed
    ) external onlyOwner nonZeroAddress(address(_priceFeed)) {
        s_priceFeeds[_token] = _priceFeed;
    }

    function getPriceFeed(
        address _token
    ) public view returns (AggregatorV3Interface) {
        if (address(s_priceFeeds[_token]) == address(0))
            revert PriceFeedDoesNotExist();
        return s_priceFeeds[_token];
    }
}
