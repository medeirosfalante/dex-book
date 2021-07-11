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
