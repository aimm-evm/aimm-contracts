# aimm-contracts

  A Managed Token, part of the AI Managed Token Suite - AIMM.

  AIMM is a DeFi market maker with community engagement tooling built in, anyone can create a ManagedToken using our factories
  permissionlessly onchain, and benefit from our on and offchain tooling to provide intelligent tax settings, buyback and liquidity
  functions. By deriving your project's ERC20 token from a ManagedToken, users can be sure by checking the verified Solidity code of:
   - Tax is hard coded as max 5/5.
   - Visibility of Maximum Tx Amount is surfaced
   - Check whether Maximum Tx Amount is frozen.
   - Check whether Tax is frozen.

  Using our ManagedTokenTreasury, users can be sure that the portion of Tax's raised to be part of the protocol cannot be rugged by
  project owners, as there are no functions to withdraw either ETH or ERC20 from the Treasury. Protocols have to enter, before Tax is taken
  on a sale, the portion they are taking for their project. This is hard coded to be capped at 50%.

  AIMM takes a revenue share of 1% of the Tax collected by the treasury, for future development of the protocol and maintence costs.
