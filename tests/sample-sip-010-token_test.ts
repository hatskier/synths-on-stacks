import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types,
} from "https://deno.land/x/clarinet@v1.0.4/index.ts";
import { assertEquals } from "https://deno.land/std@0.90.0/testing/asserts.ts";

const contractName = "sample-sip-010-token";

// Clarinet.test({
//   name: "Ensure that <...>",
//   async fn(chain: Chain, accounts: Map<string, Account>) {
//     let block = chain.mineBlock([
//       /*
//        * Add transactions with:
//        * Tx.contractCall(...)
//        */
//     ]);
//     assertEquals(block.receipts.length, 0);
//     assertEquals(block.height, 2);

//     block = chain.mineBlock([
//       /*
//        * Add transactions with:
//        * Tx.contractCall(...)
//        */
//     ]);
//     assertEquals(block.receipts.length, 0);
//     assertEquals(block.height, 3);
//   },
// });

Clarinet.test({
  name: "Ensure that balance-of function works",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const [deployer, accountA] = ["deployer", "wallet_1"].map(
      (who) => accounts.get(who)!
    );

    const totalSupplyBefore = chain.callReadOnlyFn(
      contractName,
      "get-total-supply",
      [],
      accountA.address
    );
    console.log({ totalSupplyBefore });

    const block = chain.mineBlock([
      Tx.contractCall(
        contractName,
        "mint",
        [types.uint(100) /*, types.principal(accountA.address)*/],
        accountA.address
      ),
    ]);

    console.log(block);

    const totalSupplyAfter = chain.callReadOnlyFn(
      contractName,
      "get-total-supply",
      [],
      accountA.address
    );
    console.log({ totalSupplyAfter });

    // const [receipt] = block.receipts;
    // const tokenId = receipt.result.expectOk();
    // tokenId.expectUint(1);
    // receipt.events.expectSTXTransferEvent(
    //   ~~(tokenPriceInUSD / stxusdRate),
    //   accountA.address,
    //   deployer.address
    // );
    // receipt.events.expectNonFungibleTokenMintEvent(
    //   tokenId,
    //   accountA.address,
    //   `${deployer.address}.${contractName}`,
    //   "usd-nft"
    // );
  },
});
