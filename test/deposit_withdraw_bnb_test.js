const exchange = artifacts.require("./Exchange.sol");

contract("Exchange - deposit", async (accounts) => {
  it("deposit bnb in exchange", async () => {
    const exchangeRef = await exchange.deployed();
    let totalGasCostAccumulated = 0;

    const balanceBeforeTransaction = await web3.eth.getBalance(accounts[0]);
    const depositRefValue = await web3.utils.toWei("0.01");

    const txhDeposit = await exchangeRef.depositBnb({
      from: accounts[0],
      value: depositRefValue,
    });

    const detailDeposit = await web3.eth.getTransaction(
      txhDeposit.receipt.transactionHash
    );

    totalGasCostAccumulated +=
      parseInt(txhDeposit.receipt.cumulativeGasUsed) *
      parseInt(detailDeposit.gasPrice);

    const balanceIncontract = await exchangeRef.getEthBalanceInWei.call();

    assert.equal(
      balanceIncontract.toString(),
      depositRefValue,
      "Balance is 0.01 before withdraw dex"
    );

    const balanceAfterDeposit = await web3.eth.getBalance(accounts[0]);

    assert.isAtLeast(
      parseInt(balanceBeforeTransaction) -
        (parseInt(depositRefValue) + parseInt(totalGasCostAccumulated)),
      parseInt(balanceAfterDeposit),
      " balance is total before minos fee"
    );
  });
});

contract("Exchange - withdraw", async (accounts) => {
  it("withdraw bnb in exchange", async () => {
    const exchangeRef = await exchange.deployed();
    let totalGasCostAccumulated = 0;

    const balanceBeforeTransaction = await web3.eth.getBalance(accounts[0]);

    const txhDeposit = await exchangeRef.depositBnb({
      from: accounts[0],
      value: web3.utils.toWei("0.01"),
    });

    const detailDeposit = await web3.eth.getTransaction(
      txhDeposit.receipt.transactionHash
    );

    totalGasCostAccumulated +=
      parseInt(txhDeposit.receipt.cumulativeGasUsed) *
      parseInt(detailDeposit.gasPrice);

    const txhWithdraw = await exchangeRef.withdrawBnb(web3.utils.toWei("0.01"));

    const withdrawDeposit = await web3.eth.getTransaction(
      txhWithdraw.receipt.transactionHash
    );

    totalGasCostAccumulated +=
      parseInt(txhWithdraw.receipt.cumulativeGasUsed) *
      parseInt(withdrawDeposit.gasPrice);

    const balanceIncontract = await exchangeRef.getEthBalanceInWei.call();

    assert.equal(
      balanceIncontract.toString(),
      web3.utils.toWei("0"),
      "Balance is 0 before withdraw dex"
    );

    const balanceAfterWithdrawal = await web3.eth.getBalance(accounts[0]);
    assert.isAtLeast(
      parseInt(balanceBeforeTransaction) - totalGasCostAccumulated,
      parseInt(balanceAfterWithdrawal),
      " balance is total before minos fee"
    );
  });
});
