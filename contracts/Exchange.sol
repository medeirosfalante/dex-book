// contracts/Exchange.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Exchange {
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

    function getSellOrderBook(string memory symbolName)
        public
        view
        returns (uint256[] memory, uint256[] memory)
    {
        uint8 tokenNameIndex = getSymbolIndexOrThrow(symbolName);
        uint256[] memory arrPricesSell = new uint256[](
            tokens[tokenNameIndex].amountSellPrices
        );
        uint256[] memory arrVolumesSell = new uint256[](
            tokens[tokenNameIndex].amountSellPrices
        );
        uint256 sellWhilePrice = tokens[tokenNameIndex].curSellPrice;
        uint256 sellCounter = 0;
        if (tokens[tokenNameIndex].curSellPrice > 0) {
            while (sellWhilePrice <= tokens[tokenNameIndex].highestSellPrice) {
                arrPricesSell[sellCounter] = sellWhilePrice;
                uint256 sellVolumeAtPrice = 0;
                uint256 sellOffersKey = 0;
                sellOffersKey = tokens[tokenNameIndex]
                .sellBook[sellWhilePrice]
                .offers_key;
                while (
                    sellOffersKey <=
                    tokens[tokenNameIndex]
                    .sellBook[sellWhilePrice]
                    .offers_length
                ) {
                    sellVolumeAtPrice += tokens[tokenNameIndex]
                    .sellBook[sellWhilePrice]
                    .offers[sellOffersKey]
                    .amountTokens;
                    sellOffersKey++;
                }
                arrVolumesSell[sellCounter] = sellVolumeAtPrice;
                if (
                    tokens[tokenNameIndex]
                    .sellBook[sellWhilePrice]
                    .higherPrice == 0
                ) {
                    break;
                } else {
                    sellWhilePrice = tokens[tokenNameIndex]
                    .sellBook[sellWhilePrice]
                    .higherPrice;
                }
                sellCounter++;
            }
        }
        return (arrPricesSell, arrVolumesSell);
    }

    // Returns Buy Prices Array and Buy Volume Array for each of the Prices
    function getBuyOrderBook(string memory symbolName)
        public
        view
        returns (uint256[] memory, uint256[] memory)
    {
        uint8 tokenNameIndex = getSymbolIndexOrThrow(symbolName);
        uint256[] memory arrPricesBuy = new uint256[](
            tokens[tokenNameIndex].amountBuyPrices
        );
        uint256[] memory arrVolumesBuy = new uint256[](
            tokens[tokenNameIndex].amountBuyPrices
        );

        uint256 whilePrice = tokens[tokenNameIndex].lowestBuyPrice;
        uint256 counter = 0;
        if (tokens[tokenNameIndex].curBuyPrice > 0) {
            while (whilePrice <= tokens[tokenNameIndex].curBuyPrice) {
                arrPricesBuy[counter] = whilePrice;
                uint256 buyVolumeAtPrice = 0;
                uint256 buyOffersKey = 0;

                // Obtain the Volume from Summing all Offers Mapped to a Single Price inside the Buy Order Book
                buyOffersKey = tokens[tokenNameIndex]
                .buyBook[whilePrice]
                .offers_key;
                while (
                    buyOffersKey <=
                    tokens[tokenNameIndex].buyBook[whilePrice].offers_length
                ) {
                    buyVolumeAtPrice += tokens[tokenNameIndex]
                    .buyBook[whilePrice]
                    .offers[buyOffersKey]
                    .amountTokens;
                    buyOffersKey++;
                }
                arrVolumesBuy[counter] = buyVolumeAtPrice;
                // Next whilePrice
                if (
                    whilePrice ==
                    tokens[tokenNameIndex].buyBook[whilePrice].higherPrice
                ) {
                    break;
                } else {
                    whilePrice = tokens[tokenNameIndex]
                    .buyBook[whilePrice]
                    .higherPrice;
                }
                counter++;
            }
        }
        return (arrPricesBuy, arrVolumesBuy);
    }

    function buyToken(
        string memory symbolName,
        uint256 priceInWei,
        uint256 amount
    ) public {
        uint8 tokenNameIndex = getSymbolIndexOrThrow(symbolName);
        uint256 totalAmountOfEtherNecessary = 0;
        uint256 amountOfTokensNecessary = amount;

        if (
            tokens[tokenNameIndex].amountSellPrices == 0 ||
            tokens[tokenNameIndex].curSellPrice > priceInWei
        ) {
            createBuyLimitOrderForTokensUnableToMatchWithSellOrderForBuyer(
                symbolName,
                tokenNameIndex,
                priceInWei,
                amountOfTokensNecessary,
                totalAmountOfEtherNecessary
            );
        } else {
            uint256 totalAmountOfEtherAvailable = 0;
            uint256 whilePrice = tokens[tokenNameIndex].curSellPrice;
            uint256 offers_key;
            while (whilePrice <= priceInWei && amountOfTokensNecessary > 0) {
                offers_key = tokens[tokenNameIndex]
                .sellBook[whilePrice]
                .offers_key;
                while (
                    offers_key <=
                    tokens[tokenNameIndex].sellBook[whilePrice].offers_length &&
                    amountOfTokensNecessary > 0
                ) {
                    uint256 volumeAtPriceFromAddress = tokens[tokenNameIndex]
                    .sellBook[whilePrice]
                    .offers[offers_key]
                    .amountTokens;

                    if (volumeAtPriceFromAddress <= amountOfTokensNecessary) {
                        totalAmountOfEtherAvailable =
                            volumeAtPriceFromAddress *
                            whilePrice;
                        require(
                            balanceBnbForAddress[msg.sender] >=
                                totalAmountOfEtherAvailable
                        );
                        require(
                            balanceBnbForAddress[msg.sender] -
                                totalAmountOfEtherAvailable <=
                                balanceBnbForAddress[msg.sender]
                        );
                        balanceBnbForAddress[
                            msg.sender
                        ] -= totalAmountOfEtherAvailable;

                        require(
                            balanceBnbForAddress[msg.sender] >=
                                totalAmountOfEtherAvailable
                        );
                        require(uint256(1) > uint256(0));
                        require(
                            tokenBalanceForAddress[msg.sender][tokenNameIndex] +
                                volumeAtPriceFromAddress >=
                                tokenBalanceForAddress[msg.sender][
                                    tokenNameIndex
                                ]
                        );
                        require(
                            balanceBnbForAddress[
                                tokens[tokenNameIndex]
                                .sellBook[whilePrice]
                                .offers[offers_key]
                                .who
                            ] +
                                totalAmountOfEtherAvailable >=
                                balanceBnbForAddress[
                                    tokens[tokenNameIndex]
                                    .sellBook[whilePrice]
                                    .offers[offers_key]
                                    .who
                                ]
                        );

                        tokenBalanceForAddress[msg.sender][
                            tokenNameIndex
                        ] += volumeAtPriceFromAddress;

                        tokens[tokenNameIndex]
                        .sellBook[whilePrice]
                        .offers[offers_key]
                        .amountTokens = 0;

                        balanceBnbForAddress[
                            tokens[tokenNameIndex]
                            .sellBook[whilePrice]
                            .offers[offers_key]
                            .who
                        ] += totalAmountOfEtherAvailable;
                        tokens[tokenNameIndex]
                            .sellBook[whilePrice]
                            .offers_key++;

                        amountOfTokensNecessary -= volumeAtPriceFromAddress;
                    } else {
                        require(
                            tokens[tokenNameIndex]
                            .sellBook[whilePrice]
                            .offers[offers_key]
                            .amountTokens > amountOfTokensNecessary
                        );

                        totalAmountOfEtherNecessary =
                            amountOfTokensNecessary *
                            whilePrice;

                        // Overflow Check
                        require(
                            balanceBnbForAddress[msg.sender] -
                                totalAmountOfEtherNecessary <=
                                balanceBnbForAddress[msg.sender]
                        );

                        balanceBnbForAddress[
                            msg.sender
                        ] -= totalAmountOfEtherNecessary;

                        // Overflow Check
                        require(
                            balanceBnbForAddress[
                                tokens[tokenNameIndex]
                                .sellBook[whilePrice]
                                .offers[offers_key]
                                .who
                            ] +
                                totalAmountOfEtherNecessary >=
                                balanceBnbForAddress[
                                    tokens[tokenNameIndex]
                                    .sellBook[whilePrice]
                                    .offers[offers_key]
                                    .who
                                ]
                        );

                        tokens[tokenNameIndex]
                        .sellBook[whilePrice]
                        .offers[offers_key]
                        .amountTokens -= amountOfTokensNecessary;
                        balanceBnbForAddress[
                            tokens[tokenNameIndex]
                            .sellBook[whilePrice]
                            .offers[offers_key]
                            .who
                        ] += totalAmountOfEtherNecessary;
                        tokenBalanceForAddress[msg.sender][
                            tokenNameIndex
                        ] += amountOfTokensNecessary;
                        amountOfTokensNecessary = 0;
                    }

                    if (
                        offers_key ==
                        tokens[tokenNameIndex]
                        .sellBook[whilePrice]
                        .offers_length &&
                        tokens[tokenNameIndex]
                        .sellBook[whilePrice]
                        .offers[offers_key]
                        .amountTokens ==
                        0
                    ) {
                        tokens[tokenNameIndex].amountSellPrices--;
                        if (
                            whilePrice ==
                            tokens[tokenNameIndex]
                            .sellBook[whilePrice]
                            .higherPrice ||
                            tokens[tokenNameIndex]
                            .sellBook[whilePrice]
                            .higherPrice ==
                            0
                        ) {
                            tokens[tokenNameIndex].curSellPrice = 0;
                        } else {
                            tokens[tokenNameIndex].curSellPrice = tokens[
                                tokenNameIndex
                            ]
                            .sellBook[whilePrice]
                            .higherPrice;
                            tokens[tokenNameIndex]
                            .sellBook[
                                tokens[tokenNameIndex]
                                .sellBook[whilePrice]
                                .higherPrice
                            ]
                            .lowerPrice = 0;
                        }
                    }
                    offers_key++;
                }
                whilePrice = tokens[tokenNameIndex].curSellPrice;
            }

            if (amountOfTokensNecessary > 0) {
                createBuyLimitOrderForTokensUnableToMatchWithSellOrderForBuyer(
                    symbolName,
                    tokenNameIndex,
                    priceInWei,
                    amountOfTokensNecessary,
                    totalAmountOfEtherNecessary
                );
            }
        }
    }

    function createBuyLimitOrderForTokensUnableToMatchWithSellOrderForBuyer(
        string memory symbolName,
        uint8 tokenNameIndex,
        uint256 priceInWei,
        uint256 amountOfTokensNecessary,
        uint256 totalAmountOfEtherNecessary
    ) internal {
        totalAmountOfEtherNecessary = amountOfTokensNecessary * priceInWei;

        require(totalAmountOfEtherNecessary >= amountOfTokensNecessary);
        require(totalAmountOfEtherNecessary >= priceInWei);
        require(
            balanceBnbForAddress[msg.sender] >= totalAmountOfEtherNecessary
        );
        require(
            balanceBnbForAddress[msg.sender] - totalAmountOfEtherNecessary >= 0
        );
        require(
            balanceBnbForAddress[msg.sender] - totalAmountOfEtherNecessary <=
                balanceBnbForAddress[msg.sender]
        );

        balanceBnbForAddress[msg.sender] -= totalAmountOfEtherNecessary;
        addBuyOffer(
            tokenNameIndex,
            priceInWei,
            amountOfTokensNecessary,
            msg.sender
        );
    }
}
