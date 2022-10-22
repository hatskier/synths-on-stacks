import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types,
} from "https://deno.land/x/clarinet@v1.0.4/index.ts";
import { assertEquals } from "https://deno.land/std@0.90.0/testing/asserts.ts";

const contractName = "synth";
const errors = {
  "already-initialized": "u7",
  "not-initialized": "u12",
};

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
          types.buff("Mock redstone payload"),
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
          types.buff("Mock redstone payload"),
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
  async fn(chain: Chain, accounts: Map<string, Account>) {},
});

Clarinet.test({
  name: "Should not mint too much tokens",
  async fn(chain: Chain, accounts: Map<string, Account>) {},
});

Clarinet.test({
  name: "Should not remove too much collateral",
  async fn(chain: Chain, accounts: Map<string, Account>) {},
});

Clarinet.test({
  name: "Should properly liquidate an insolvent principal",
  async fn(chain: Chain, accounts: Map<string, Account>) {},
});

Clarinet.test({
  name: "Should not liquidate a solvent principal",
  async fn(chain: Chain, accounts: Map<string, Account>) {},
});
