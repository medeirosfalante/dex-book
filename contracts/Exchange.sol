// contracts/Exchange.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

    struct Offer {
        uint256 amountTokens;
        address who;
    }

    struct OrderBook {
        uint256 higherPrice;
        uint256 lowerPrice;
        mapping(uint256 => Offer) offers;
        uint256 offers_key;
        uint256 offers_length;
    }

    struct Token {
        address tokenContract;
        string symbolName;
        mapping(uint256 => OrderBook) buyBook;
        uint256 curBuyPrice;
        uint256 lowestBuyPrice;
        uint256 amountBuyPrices;
        mapping(uint256 => OrderBook) sellBook;
        uint256 curSellPrice;
        uint256 highestSellPrice;
        uint256 amountSellPrices;
    }

    mapping(uint8 => Token) tokens;
    uint8 symbolNameIndex;

    mapping(address => mapping(uint8 => uint256)) tokenBalanceForAddress;

    mapping(address => uint256) balanceBnbForAddress;

    function stringsEqual(string storage _a, string memory _b)
        internal
        view
        returns (bool)
    {
        bytes storage a = bytes(_a);
        bytes memory b = bytes(_b);

        if (keccak256(a) != keccak256(b)) {
            return false;
        }
        return true;
    }

    function getSymbolIndexOrThrow(string memory symbolName)
        internal
        view
        returns (uint8)
    {
        uint8 index = getSymbolIndex(symbolName);
        require(index > 0);
        return index;
    }

    function hasToken(string memory symbolName) public view returns (bool) {
        uint8 index = getSymbolIndex(symbolName);
        if (index == 0) {
            return false;
        }
        return true;
    }

    function getSymbolIndex(string memory symbolName)
        internal
        view
        returns (uint8)
    {
        for (uint8 i = 1; i <= symbolNameIndex; i++) {
            if (stringsEqual(tokens[i].symbolName, symbolName)) {
                return i;
            }
        }
        return 0;
    }

    function depositBnb() public payable {
        require(
            balanceBnbForAddress[msg.sender] + msg.value >=
                balanceBnbForAddress[msg.sender]
        );
        balanceBnbForAddress[msg.sender] += msg.value;
    }

    function withdrawBnb(uint256 amountInWei) public {
        require(balanceBnbForAddress[msg.sender] - amountInWei >= 0);
        require(
            balanceBnbForAddress[msg.sender] - amountInWei <=
                balanceBnbForAddress[msg.sender]
        );

        balanceBnbForAddress[msg.sender] -= amountInWei;

        payable(msg.sender).transfer(amountInWei);
    }

