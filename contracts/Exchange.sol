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
        pure
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
        uint8 symbolNameIndexKey = getSymbolIndexOrThrow(symbolName);
        require(tokens[symbolNameIndexKey].tokenContract != address(0));

        IERC20 token = IERC20(tokens[symbolNameIndexKey].tokenContract);

        require(
            token.transferFrom(msg.sender, address(this), amountTokens) == true
        );
        require(
            tokenBalanceForAddress[msg.sender][symbolNameIndexKey] +
                amountTokens >=
                tokenBalanceForAddress[msg.sender][symbolNameIndexKey]
        );
        tokenBalanceForAddress[msg.sender][symbolNameIndexKey] += amountTokens;
    }

    function withdrawToken(string memory symbolName, uint256 amountTokens)
        public
    {
        uint8 symbolNameIndexKey = getSymbolIndexOrThrow(symbolName);
        require(tokens[symbolNameIndexKey].tokenContract != address(0));

        IERC20 token = IERC20(tokens[symbolNameIndexKey].tokenContract);
        require(
            tokenBalanceForAddress[msg.sender][symbolNameIndexKey] -
                amountTokens >=
                0
        );
        require(
            tokenBalanceForAddress[msg.sender][symbolNameIndexKey] -
                amountTokens <=
                tokenBalanceForAddress[msg.sender][symbolNameIndexKey]
        );
        tokenBalanceForAddress[msg.sender][symbolNameIndexKey] -= amountTokens;
        require(token.transfer(msg.sender, amountTokens) == true);
    }

    function getBalance(string memory symbolName)
        public
        view
        returns (uint256)
    {
        uint8 symbolNameIndexKey = getSymbolIndexOrThrow(symbolName);
        return tokenBalanceForAddress[msg.sender][symbolNameIndexKey];
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

    function addBuyOffer(
        uint8 tokenIndex,
        uint256 priceInWei,
        uint256 amount,
        address who
    ) internal {
        tokens[tokenIndex].buyBook[priceInWei].offers_length++;

        tokens[tokenIndex].buyBook[priceInWei].offers[
            tokens[tokenIndex].buyBook[priceInWei].offers_length
        ] = Offer(amount, who);

        if (tokens[tokenIndex].buyBook[priceInWei].offers_length == 1) {
            tokens[tokenIndex].buyBook[priceInWei].offers_key = 1;
            tokens[tokenIndex].amountBuyPrices++;
            uint256 curBuyPrice = tokens[tokenIndex].curBuyPrice;
            uint256 lowestBuyPrice = tokens[tokenIndex].lowestBuyPrice;
            if (lowestBuyPrice == 0 || lowestBuyPrice > priceInWei) {
                if (curBuyPrice == 0) {
                    tokens[tokenIndex].curBuyPrice = priceInWei;

                    tokens[tokenIndex]
                    .buyBook[priceInWei]
                    .higherPrice = priceInWei;

                    tokens[tokenIndex].buyBook[priceInWei].lowerPrice = 0;
                } else {
                    tokens[tokenIndex]
                    .buyBook[lowestBuyPrice]
                    .lowerPrice = priceInWei;
                    tokens[tokenIndex]
                    .buyBook[priceInWei]
                    .higherPrice = lowestBuyPrice;
                    tokens[tokenIndex].buyBook[priceInWei].lowerPrice = 0;
                }
                tokens[tokenIndex].lowestBuyPrice = priceInWei;
            } else if (curBuyPrice < priceInWei) {
                tokens[tokenIndex]
                .buyBook[curBuyPrice]
                .higherPrice = priceInWei;
                tokens[tokenIndex].buyBook[priceInWei].higherPrice = priceInWei;
                tokens[tokenIndex].buyBook[priceInWei].lowerPrice = curBuyPrice;
                tokens[tokenIndex].curBuyPrice = priceInWei;
            } else {
                uint256 buyPrice = tokens[tokenIndex].curBuyPrice;
                bool weFoundLocation = false;
                while (buyPrice > 0 && !weFoundLocation) {
                    if (
                        buyPrice < priceInWei &&
                        tokens[tokenIndex].buyBook[buyPrice].higherPrice >
                        priceInWei
                    ) {
                        tokens[tokenIndex]
                        .buyBook[priceInWei]
                        .lowerPrice = buyPrice;
                        tokens[tokenIndex]
                        .buyBook[priceInWei]
                        .higherPrice = tokens[tokenIndex]
                        .buyBook[buyPrice]
                        .higherPrice;

                        tokens[tokenIndex]
                        .buyBook[
                            tokens[tokenIndex].buyBook[buyPrice].higherPrice
                        ]
                        .lowerPrice = priceInWei;

                        tokens[tokenIndex]
                        .buyBook[buyPrice]
                        .higherPrice = priceInWei;

                        weFoundLocation = true;
                    }
                    buyPrice = tokens[tokenIndex].buyBook[buyPrice].lowerPrice;
                }
            }
        }
    }

    function addSellOffer(
        uint8 tokenIndex,
        uint256 priceInWei,
        uint256 amount,
        address who
    ) internal {
        tokens[tokenIndex].sellBook[priceInWei].offers_length++;

        tokens[tokenIndex].sellBook[priceInWei].offers[
            tokens[tokenIndex].sellBook[priceInWei].offers_length
        ] = Offer(amount, who);

        if (tokens[tokenIndex].sellBook[priceInWei].offers_length == 1) {
            tokens[tokenIndex].sellBook[priceInWei].offers_key = 1;
            tokens[tokenIndex].amountSellPrices++;

            uint256 curSellPrice = tokens[tokenIndex].curSellPrice;
            uint256 highestSellPrice = tokens[tokenIndex].highestSellPrice;

            if (highestSellPrice == 0 || highestSellPrice < priceInWei) {
                if (curSellPrice == 0) {
                    tokens[tokenIndex].curSellPrice = priceInWei;
                    tokens[tokenIndex].sellBook[priceInWei].higherPrice = 0;
                    tokens[tokenIndex].sellBook[priceInWei].lowerPrice = 0;
                } else {
                    tokens[tokenIndex]
                    .sellBook[highestSellPrice]
                    .higherPrice = priceInWei;
                    tokens[tokenIndex]
                    .sellBook[priceInWei]
                    .lowerPrice = highestSellPrice;
                    tokens[tokenIndex].sellBook[priceInWei].higherPrice = 0;
                }
                tokens[tokenIndex].highestSellPrice = priceInWei;
            } else if (curSellPrice > priceInWei) {
                tokens[tokenIndex]
                .sellBook[curSellPrice]
                .lowerPrice = priceInWei;
                tokens[tokenIndex]
                .sellBook[priceInWei]
                .higherPrice = curSellPrice;
                tokens[tokenIndex].sellBook[priceInWei].lowerPrice = 0;
                tokens[tokenIndex].curSellPrice = priceInWei;
            } else {
                uint256 sellPrice = tokens[tokenIndex].curSellPrice;
                bool weFoundLocation = false;

                while (sellPrice > 0 && !weFoundLocation) {
                    if (
                        sellPrice < priceInWei &&
                        tokens[tokenIndex].sellBook[sellPrice].higherPrice >
                        priceInWei
                    ) {
                        tokens[tokenIndex]
                        .sellBook[priceInWei]
                        .lowerPrice = sellPrice;
                        tokens[tokenIndex]
                        .sellBook[priceInWei]
                        .higherPrice = tokens[tokenIndex]
                        .sellBook[sellPrice]
                        .higherPrice;

                        tokens[tokenIndex]
                        .sellBook[
                            tokens[tokenIndex].sellBook[sellPrice].higherPrice
                        ]
                        .lowerPrice = priceInWei;

                        tokens[tokenIndex]
                        .sellBook[sellPrice]
                        .higherPrice = priceInWei;

                        weFoundLocation = true;
                    }

                    sellPrice = tokens[tokenIndex]
                    .sellBook[sellPrice]
                    .higherPrice;
                }
            }
        }
    }

    function cancelOrder(
        string memory symbolName,
        bool isSellOrder,
        uint256 priceInWei,
        uint256 offerKey
    ) public {
        uint8 symbolNameIndexKey = getSymbolIndexOrThrow(symbolName);

        if (isSellOrder) {
            require(
                tokens[symbolNameIndexKey]
                .sellBook[priceInWei]
                .offers[offerKey]
                .who == msg.sender
            );

            uint256 tokensAmount = tokens[symbolNameIndexKey]
            .sellBook[priceInWei]
            .offers[offerKey]
            .amountTokens;

            require(
                tokenBalanceForAddress[msg.sender][symbolNameIndexKey] +
                    tokensAmount >=
                    tokenBalanceForAddress[msg.sender][symbolNameIndexKey]
            );

            tokenBalanceForAddress[msg.sender][
                symbolNameIndexKey
            ] += tokensAmount;
            tokens[symbolNameIndexKey]
            .sellBook[priceInWei]
            .offers[offerKey]
            .amountTokens = 0;
        } else {
            require(
                tokens[symbolNameIndexKey]
                .buyBook[priceInWei]
                .offers[offerKey]
                .who == msg.sender
            );
            uint256 etherToRefund = tokens[symbolNameIndexKey]
            .buyBook[priceInWei]
            .offers[offerKey]
            .amountTokens * priceInWei;

            require(
                balanceBnbForAddress[msg.sender] + etherToRefund >=
                    balanceBnbForAddress[msg.sender]
            );

            balanceBnbForAddress[msg.sender] += etherToRefund;
            tokens[symbolNameIndexKey]
            .buyBook[priceInWei]
            .offers[offerKey]
            .amountTokens = 0;
        }
    }

    function sellToken(
        string memory symbolName,
        uint256 priceInWei,
        uint256 amount
    ) public payable {
        uint8 tokenNameIndex = getSymbolIndexOrThrow(symbolName);
        uint256 totalAmountOfEtherNecessary = 0;
        uint256 totalAmountOfEtherAvailable = 0;

        uint256 amountOfTokensNecessary = amount;

        if (
            tokens[tokenNameIndex].amountBuyPrices == 0 ||
            tokens[tokenNameIndex].curBuyPrice < priceInWei
        ) {
            createSellLimitOrderForTokensUnableToMatchWithBuyOrderForSeller(
                symbolName,
                tokenNameIndex,
                priceInWei,
                amountOfTokensNecessary,
                totalAmountOfEtherNecessary
            );
        } else {
            uint256 whilePrice = tokens[tokenNameIndex].curBuyPrice;
            uint256 offers_key;

            while (whilePrice >= priceInWei && amountOfTokensNecessary > 0) {
                offers_key = tokens[tokenNameIndex]
                .buyBook[whilePrice]
                .offers_key;

                while (
                    offers_key <=
                    tokens[tokenNameIndex].buyBook[whilePrice].offers_length &&
                    amountOfTokensNecessary > 0
                ) {
                    uint256 volumeAtPriceFromAddress = tokens[tokenNameIndex]
                    .buyBook[whilePrice]
                    .offers[offers_key]
                    .amountTokens;

                    if (volumeAtPriceFromAddress <= amountOfTokensNecessary) {
                        totalAmountOfEtherAvailable =
                            volumeAtPriceFromAddress *
                            whilePrice;

                        require(
                            tokenBalanceForAddress[msg.sender][
                                tokenNameIndex
                            ] >= volumeAtPriceFromAddress
                        );

                        tokenBalanceForAddress[msg.sender][
                            tokenNameIndex
                        ] -= volumeAtPriceFromAddress;

                        require(
                            tokenBalanceForAddress[msg.sender][tokenNameIndex] -
                                volumeAtPriceFromAddress >=
                                0
                        );

                        require(
                            tokenBalanceForAddress[
                                tokens[tokenNameIndex]
                                .buyBook[whilePrice]
                                .offers[offers_key]
                                .who
                            ][tokenNameIndex] +
                                volumeAtPriceFromAddress >=
                                tokenBalanceForAddress[
                                    tokens[tokenNameIndex]
                                    .buyBook[whilePrice]
                                    .offers[offers_key]
                                    .who
                                ][tokenNameIndex]
                        );

                        require(
                            balanceBnbForAddress[msg.sender] +
                                totalAmountOfEtherAvailable >=
                                balanceBnbForAddress[msg.sender]
                        );

                        tokenBalanceForAddress[
                            tokens[tokenNameIndex]
                            .buyBook[whilePrice]
                            .offers[offers_key]
                            .who
                        ][tokenNameIndex] += volumeAtPriceFromAddress;

                        tokens[tokenNameIndex]
                        .buyBook[whilePrice]
                        .offers[offers_key]
                        .amountTokens = 0;

                        balanceBnbForAddress[
                            msg.sender
                        ] += totalAmountOfEtherAvailable;

                        tokens[tokenNameIndex].buyBook[whilePrice].offers_key++;

                        amountOfTokensNecessary -= volumeAtPriceFromAddress;
                    } else {
                        require(
                            volumeAtPriceFromAddress - amountOfTokensNecessary >
                                0
                        );

                        totalAmountOfEtherNecessary =
                            amountOfTokensNecessary *
                            whilePrice;

                        require(
                            tokenBalanceForAddress[msg.sender][
                                tokenNameIndex
                            ] >= amountOfTokensNecessary
                        );

                        tokenBalanceForAddress[msg.sender][
                            tokenNameIndex
                        ] -= amountOfTokensNecessary;

                        require(
                            tokenBalanceForAddress[msg.sender][
                                tokenNameIndex
                            ] >= amountOfTokensNecessary
                        );
                        require(
                            balanceBnbForAddress[msg.sender] +
                                totalAmountOfEtherNecessary >=
                                balanceBnbForAddress[msg.sender]
                        );
                        require(
                            tokenBalanceForAddress[
                                tokens[tokenNameIndex]
                                .buyBook[whilePrice]
                                .offers[offers_key]
                                .who
                            ][tokenNameIndex] +
                                amountOfTokensNecessary >=
                                tokenBalanceForAddress[
                                    tokens[tokenNameIndex]
                                    .buyBook[whilePrice]
                                    .offers[offers_key]
                                    .who
                                ][tokenNameIndex]
                        );

                        tokens[tokenNameIndex]
                        .buyBook[whilePrice]
                        .offers[offers_key]
                        .amountTokens -= amountOfTokensNecessary;

                        balanceBnbForAddress[
                            msg.sender
                        ] += totalAmountOfEtherNecessary;

                        tokenBalanceForAddress[
                            tokens[tokenNameIndex]
                            .buyBook[whilePrice]
                            .offers[offers_key]
                            .who
                        ][tokenNameIndex] += amountOfTokensNecessary;

                        amountOfTokensNecessary = 0;
                    }

                    if (
                        offers_key ==
                        tokens[tokenNameIndex]
                        .buyBook[whilePrice]
                        .offers_length &&
                        tokens[tokenNameIndex]
                        .buyBook[whilePrice]
                        .offers[offers_key]
                        .amountTokens ==
                        0
                    ) {
                        tokens[tokenNameIndex].amountBuyPrices--;
                        if (
                            whilePrice ==
                            tokens[tokenNameIndex]
                            .buyBook[whilePrice]
                            .lowerPrice ||
                            tokens[tokenNameIndex]
                            .buyBook[whilePrice]
                            .lowerPrice ==
                            0
                        ) {
                            tokens[tokenNameIndex].curBuyPrice = 0;
                        } else {
                            tokens[tokenNameIndex].curBuyPrice = tokens[
                                tokenNameIndex
                            ]
                            .buyBook[whilePrice]
                            .lowerPrice;

                            tokens[tokenNameIndex]
                            .buyBook[
                                tokens[tokenNameIndex]
                                .buyBook[whilePrice]
                                .lowerPrice
                            ]
                            .higherPrice = tokens[tokenNameIndex].curBuyPrice;
                        }
                    }
                    offers_key++;
                }

                whilePrice = tokens[tokenNameIndex].curBuyPrice;
            }

            if (amountOfTokensNecessary > 0) {
                createSellLimitOrderForTokensUnableToMatchWithBuyOrderForSeller(
                    symbolName,
                    tokenNameIndex,
                    priceInWei,
                    amountOfTokensNecessary,
                    totalAmountOfEtherNecessary
                );
            }
        }
    }

    function createSellLimitOrderForTokensUnableToMatchWithBuyOrderForSeller(
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
            tokenBalanceForAddress[msg.sender][tokenNameIndex] >=
                amountOfTokensNecessary
        );
        require(
            tokenBalanceForAddress[msg.sender][tokenNameIndex] -
                amountOfTokensNecessary >=
                0
        );
        require(
            balanceBnbForAddress[msg.sender] + totalAmountOfEtherNecessary >=
                balanceBnbForAddress[msg.sender]
        );

        tokenBalanceForAddress[msg.sender][
            tokenNameIndex
        ] -= amountOfTokensNecessary;

        addSellOffer(
            tokenNameIndex,
            priceInWei,
            amountOfTokensNecessary,
            msg.sender
        );
    }


      function addToken(string symbolName, address bep20TokenAddress) public onlyowner {
        require(!hasToken(symbolName));
        symbolNameIndex++;
        tokens[symbolNameIndex].symbolName = symbolName;
        tokens[symbolNameIndex].tokenContract = bep20TokenAddress;
    }
}
