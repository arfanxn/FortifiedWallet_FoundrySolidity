// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {MultiOwnable} from "src/MultiOwnable.sol";

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
     * @dev address of the caller user
     */
    address private caller;
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
        _initializeMultiOwnable();

        uint256 chainId = block.chainid;

        if (chainId == MAINNET_CHAIN_ID) _setMainnetConfig();
        else if (chainId == SEPOLIA_CHAIN_ID) _setSepoliaConfig();
        else if (chainId == LOCAL_CHAIN_ID) _setLocalConfig();
        else revert InvalidChainId();
    }

    // function getMainnetConfig() public pure returns (NetworkConfig memory) {
    //     return NetworkConfig();
    // }

    //==============================================================
    //                     Getters and setters
    //==============================================================

    /**
     * @dev get the caller address
     * @return address of the caller
     */
    function getCaller() public view returns (address) {
        return caller;
    }

    /**
     * @dev set the caller address
     * @param _caller address of the caller
     */
    function setCaller(address _caller) public onlyOwner {
        caller = _caller;
    }

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
    //                     Utility functions
    //==============================================================

    function _initializeMultiOwnable() private {
        address[] memory _owners = new address[](1);
        _owners[0] = msg.sender;
        super.initialize(_owners);
    }

    /**
     * @dev Sets the tokens and price feeds to their mainnet values.
     * @notice This function is only called once when the contract is first deployed.
     */
    function _setMainnetConfig() private {
        // set tokens
        setToken(HelperConfig.Token.ETH, address(0));
        setToken(
            HelperConfig.Token.WETH,
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
        );
        setToken(
            HelperConfig.Token.USDC,
            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
        );
        setToken(
            HelperConfig.Token.MKR,
            0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2
        );
        // set price feeds
        setPriceFeed(
            HelperConfig.Token.WETH,
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        );
        setPriceFeed(
            HelperConfig.Token.ETH,
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        );
        setPriceFeed(
            HelperConfig.Token.USDC,
            0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6
        );
        setPriceFeed(
            HelperConfig.Token.MKR,
            0xec1D1B3b0443256cc3860e24a46F108e699484Aa
        );
    }

    function _setSepoliaConfig() private {
        // set tokens
        setToken(HelperConfig.Token.ETH, address(0));
        setToken(
            HelperConfig.Token.WETH,
            0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9
        );
        setToken(
            HelperConfig.Token.USDC,
            0xf08A50178dfcDe18524640EA6618a1f965821715
        );
        setToken(
            HelperConfig.Token.MKR,
            0x67E0256715Dbe4A72CDBf657D8866b8E6Ba4463E
        );
        // set price feeds
        setPriceFeed(
            HelperConfig.Token.WETH,
            0x694AA1769357215DE4FAC081bf1f309aDC325306
        );
        setPriceFeed(
            HelperConfig.Token.ETH,
            0x694AA1769357215DE4FAC081bf1f309aDC325306
        );
        setPriceFeed(
            HelperConfig.Token.USDC,
            0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E
        );
    }

    function _setLocalConfig() private {
        // Do nothing
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
