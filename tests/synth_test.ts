import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types,
} from "https://deno.land/x/clarinet@v1.0.4/index.ts";
import { assertEquals } from "https://deno.land/std@0.90.0/testing/asserts.ts";

const contractName = "synth";
const pseudoInfinity = "u10000000000000000000";
const errors = {
  "already-initialized": "u7",
  "not-initialized": "u12",
};
const mockRedstonePayload = types.buff("Mock redstone payload");

Clarinet.test({
  name: "Should not interact before initializing",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    // Should not add collateral
    let block = chain.mineBlock([
      Tx.contractCall(
        contractName,
        "add-collateral",
        [
          types.uint(100000), // stx-amount
        ],
        accounts.get("wallet_1").address
      ),
    ]);
    assertEquals(
      block.receipts[0].result.expectErr(),
      errors["not-initialized"]
    );

    // Should not remove collateral
    block = chain.mineBlock([
      Tx.contractCall(
        contractName,
        "remove-collateral",
        [
          types.uint(100000), // stx-amount
          mockRedstonePayload,
        ],
        accounts.get("wallet_1").address
      ),
    ]);
    assertEquals(
      block.receipts[0].result.expectErr(),
      errors["not-initialized"]
    );

    // Should not mint
    block = chain.mineBlock([
      Tx.contractCall(
        contractName,
        "mint",
        [
          types.uint(100000), // stx-amount
          mockRedstonePayload,
        ],
        accounts.get("wallet_1").address
      ),
    ]);
    assertEquals(
      block.receipts[0].result.expectErr(),
      errors["not-initialized"]
    );
  },
});

Clarinet.test({
  name: "Should not initialize twice",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const initializeCall = Tx.contractCall(
      contractName,
      "initialize",
      [
        types.ascii("Synthetic AAPL"), // name
        types.ascii("SYNTH-AAPL"), // symbol
        types.ascii("AAPL"), // data feed id
      ],
      accounts.get("deployer").address
    );

    // Should correctly initialize
    let block = chain.mineBlock([initializeCall]);
    block.receipts[0].result.expectOk();

    // Should fail
    block = chain.mineBlock([initializeCall]);
    const errId = block.receipts[0].result.expectErr();
    assertEquals(errId, errors["already-initialized"]);
  },
});

Clarinet.test({
  name: "Should properly add collateral, mint, and burn",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const [deployer, accountA] = ["deployer", "wallet_1"].map(
      (who) => accounts.get(who)!
    );

    // Should correctly initialize
    let block = chain.mineBlock([
      Tx.contractCall(
        contractName,
        "initialize",
        [
          types.ascii("Synthetic AAPL"), // name
          types.ascii("SYNTH-AAPL"), // symbol
          types.ascii("AAPL"), // data feed id
        ],
        deployer.address
      ),
    ]);
    block.receipts[0].result.expectOk();

    // Should add collateral
    block = chain.mineBlock([
      Tx.contractCall(
        contractName,
        "add-collateral",
        [
          types.uint(100000), // stx-amount
        ],
        accountA.address
      ),
    ]);
    block.receipts[0].result.expectOk();

    // Should properly calculate solvency ratio
    const solvencyRatio1 = chain.callReadOnlyFn(
      contractName,
      "get-solvency-ratio",
      [types.principal(accountA.address)],
      accountA.address
    );
    assertEquals(solvencyRatio1.result, pseudoInfinity);

    // Should properly calculate user balance
    const userSynthBalance1 = chain.callReadOnlyFn(
      contractName,
      "get-balance",
      [types.principal(accountA.address)],
      accountA.address
    );
    assertEquals(userSynthBalance1.result, "(ok u0)");

    // Should properly mint
    block = chain.mineBlock([
      Tx.contractCall(
        contractName,
        "mint",
        [
          types.uint(100), // synth-aapl-amount
          mockRedstonePayload,
        ],
        accountA.address
      ),
    ]);
    block.receipts[0].result.expectOk();

    // Solvency should have been updated
    const solvencyRatio2 = chain.callReadOnlyFn(
      contractName,
      "get-solvency-ratio",
      [types.principal(accountA.address)],
      accountA.address
    );
    assertEquals(solvencyRatio2.result, "u200000");

    // User balance should have been updated
    const userSynthBalance2 = chain.callReadOnlyFn(
      contractName,
      "get-balance",
      [types.principal(accountA.address)],
      accountA.address
    );
    assertEquals(userSynthBalance2.result, "(ok u100)");

    // Should burn
    block = chain.mineBlock([
      Tx.contractCall(
        contractName,
        "burn",
        [
          types.uint(50), // synth-aapl-amount
        ],
        accountA.address
      ),
    ]);
    block.receipts[0].result.expectOk();

    // Solvency should have been updated
    const solvencyRatio3 = chain.callReadOnlyFn(
      contractName,
      "get-solvency-ratio",
      [types.principal(accountA.address)],
      accountA.address
    );
    assertEquals(solvencyRatio3.result, "u400000");

    // User balance should have been updated
    const userSynthBalance3 = chain.callReadOnlyFn(
      contractName,
      "get-balance",
      [types.principal(accountA.address)],
      accountA.address
    );
    assertEquals(userSynthBalance3.result, "(ok u50)");
  },
});
