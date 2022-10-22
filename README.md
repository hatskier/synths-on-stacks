# synths-on-stacks

Synthetic asset token collateralized by STX and powered by RedStone oracles.

## Motivation

Synthetic digital assets are revolutionizing decentralized finance by offering access and liquidity to investors worldwide without any restrictions. Through tokenization, people can access investment opportunities that might otherwise be impractical for their situations. It democratizes finance and provides increased access to investments on-chain.

Protocols like Synthetix, MakerDAO, Cream Finance and UMA have already proven the viability of the concept. The total market of synthetic assets today has reached billions of dollars, showing the real need of synthetic assets.

That's why I decided to implement a standard for synthetic assets in clarity. It can be used to deploy a lot of synthetic assets on stacks (Redstone currently supports [prices for >1K different assets](https://app.redstone.finance/), including crypto, stocks, commodities, currencies, and many more). It will help to attract more funds to the stacks blockchain and will give an additional utility to the exisiting STX holders.

## How it works

### Compatible with sip-010-trait

The contract implements the sip-010-trait trait, so it can be used as a normal fungible token. E.g. users can transfer it or even exchange using DEXes built on Stacks.

### Collateralized debt position

Implementation is based on the popular and battle-tested CDP (collateralized debt position) pattern. Minting synthetic tokens could be viewed as increasing the debt that needs to be backed by adequate collateral. The collateral of every user is kept in a segregated account limiting personal risk.

### Basic roles and motivations

#### Token minters

Token minters can short undrlying assets (e.g. stocks, indexes, commodities, currencies) against STX using the steps below

- Mint a synthetic asset
- Sell it for STX (e.g. on a decentralized exchange)
- Wait for STX price to grow or for the underlying asset price to fall (or both :))
- Buy synths again on a DEX (spending less STX than before)
- Burn synths and get back the STX collateral

#### Liquidators

Liquidators are incentivised to keep track of solvency of the minters. If they notice that a minter is insolvent, they can liquidate them by repaying the debt for the insolvent minter and getting their collateral. A minter becomes insolvent if their solvency ratio falls below 120%, which gives enough time for liquidators to buy synths from the market, burn and gain profit from those activities.

#### Traders

You've probably noticed, that for both minters and liquidators it's quite important to have a liquid exchange where the synthetic assets can be bought and sold. Traders can help to achieve this liquidity by speculating on the underlying assets price.

### RedStone oracles

All synthetic assets heavily rely on the pricing data from oracles, that's why it's crucial to have a secure oracle integration in place. Implementation of this token is supposed to be used with the redstone oracle data. You can read more about [RedStone on Stacks here.](https://stacks.org/redstone)

## Next steps

- Integration with the new version of redstone-stacks-connector
- More tests for edge cases
- Prepare UI for minters
- Prepare bots for liquidation
