const Migrations = artifacts.require("Migrations");
const Exchange = artifacts.require("Exchange");

module.exports = function (deployer) {
  deployer.deploy(Migrations);
  deployer.deploy(Exchange);
};
