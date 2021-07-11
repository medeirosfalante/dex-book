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

    function getEthBalanceInWei() public view returns (uint256) {
        return balanceBnbForAddress[msg.sender];
    }

    function depositToken(string memory symbolName, uint256 amountTokens)
        public
    {
        uint8 symbolNameIndex = getSymbolIndexOrThrow(symbolName);
        require(tokens[symbolNameIndex].tokenContract != address(0));

        IERC20 token = IERC20(tokens[symbolNameIndex].tokenContract);

        require(
            token.transferFrom(msg.sender, address(this), amountTokens) == true
        );
        require(
            tokenBalanceForAddress[msg.sender][symbolNameIndex] +
                amountTokens >=
                tokenBalanceForAddress[msg.sender][symbolNameIndex]
        );
        tokenBalanceForAddress[msg.sender][symbolNameIndex] += amountTokens;
    }

    function withdrawToken(string memory symbolName, uint256 amountTokens)
        public
    {
        uint8 symbolNameIndex = getSymbolIndexOrThrow(symbolName);
        require(tokens[symbolNameIndex].tokenContract != address(0));

        IERC20 token = IERC20(tokens[symbolNameIndex].tokenContract);
        require(
            tokenBalanceForAddress[msg.sender][symbolNameIndex] -
                amountTokens >=
                0
        );
        require(
            tokenBalanceForAddress[msg.sender][symbolNameIndex] -
                amountTokens <=
                tokenBalanceForAddress[msg.sender][symbolNameIndex]
        );
        tokenBalanceForAddress[msg.sender][symbolNameIndex] -= amountTokens;
        require(token.transfer(msg.sender, amountTokens) == true);
    }

    function getBalance(string memory symbolName)
        public
        view
        returns (uint256)
    {
        uint8 symbolNameIndex = getSymbolIndexOrThrow(symbolName);
        return tokenBalanceForAddress[msg.sender][symbolNameIndex];
    }
}
