// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {MultiOwnable} from "src/libraries/MultiOwnable.sol";

/*
TODO: creates HelperCofig
    - add it in deployer, constructor and so on
    - fix it later
*/

contract HelperConfig is MultiOwnable {
    error InvalidChainId();

    enum Token {
        ETH,
        WETH,
        USDC,
        MKR,
        /* and so on... */
        length // Tracks enum length
    }

    /**
     * @dev address of the PriceConsumer contract
     */
    address private priceConsumer;
    /**
     * @dev address of the WalletFactory contract
     */
    address private walletFactory;
    /**
     * @dev addresses of tokens
     */
    mapping(HelperConfig.Token => address) private tokens;
    /**
     * @dev price feed addresses
     */
    mapping(HelperConfig.Token => address) private priceFeeds;

    /**
     * @dev Chain IDs
     */
    uint256 public constant MAINNET_CHAIN_ID = 1;
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    //==============================================================
    //                          Modifiers
    //==============================================================

    /**
     * @dev constructor
     */
    constructor() {
        _initialize();

        uint256 chainId = block.chainid;

        if (chainId == MAINNET_CHAIN_ID) {
            // TODO
        } else if (chainId == LOCAL_CHAIN_ID) {
            // TODO
        } else {
            revert InvalidChainId();
        }
    }

    // function getMainnetConfig() public pure returns (NetworkConfig memory) {
    //     return NetworkConfig();
    // }

    //==============================================================
    //                     Getters and setters
    //==============================================================

    /**
     * @dev get the PriceConsumer contract address
     * @return address of the PriceConsumer contract
     */
    function getPriceConsumer() public view returns (address) {
        return priceConsumer;
    }

    /**
     * @dev set the PriceConsumer contract address
     * @param _priceConsumer address of the PriceConsumer contract
     */
    function setPriceConsumer(address _priceConsumer) public onlyOwner {
        priceConsumer = _priceConsumer;
    }

    /**
     * @dev get the WalletFactory contract address
     * @return address of the WalletFactory contract
     */
    function getWalletFactory() public view returns (address) {
        return walletFactory;
    }

    /**
     * @dev set the WalletFactory contract address
     * @param _walletFactory address of the WalletFactory contract
     */
    function setWalletFactory(address _walletFactory) public onlyOwner {
        walletFactory = _walletFactory;
    }

    function getToken(HelperConfig.Token _name) public view returns (address) {
        return tokens[_name];
    }

    function setToken(
        HelperConfig.Token _name,
        address _token
    ) public onlyOwner {
        tokens[_name] = _token;
    }

    function getPriceFeed(
        HelperConfig.Token _name
    ) public view returns (address) {
        return priceFeeds[_name];
    }

    function setPriceFeed(
        HelperConfig.Token _name,
        address _priceFeed
    ) public onlyOwner {
        priceFeeds[_name] = _priceFeed;
    }

    //==============================================================
    //                     Inline helper functions
    //==============================================================

    function _initialize() private {
        address[] memory _owners = new address[](1);
        _owners[0] = msg.sender;
        super.initialize(_owners);
    }

    function getTokenEnumValues()
        public
        pure
        returns (HelperConfig.Token[] memory enums)
    {
        uint256 tokensLength = uint256(HelperConfig.Token.length);
        enums = new HelperConfig.Token[](tokensLength);
        for (uint256 i = 0; i < tokensLength; i++) {
            enums[i] = HelperConfig.Token(i);
        }
        return enums;
    }
}
