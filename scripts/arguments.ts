[
  'MINT_PASS_NAME',
  'MINT_PASS_SYMBOL',
  'MINT_PASS_BASE_TOKEN_URI',
  'MINT_PASS_TOTAL_BIDS_LIMIT',
  'MINT_PASS_MINIMUM_BID_AMOUNT',
  'MINT_PASS_START',
  'MINT_PASS_AUCTION_DURATION',
  'SUBSCRIPTION_ID',
  'VRF_COORDINATOR_ADDRESS',
  'LINK_TOKEN_ADDRESS',
  'VRF_KEY_HASH',
  'SCION_NAME',
  'SCION_SYMBOL',
  'SOUL_NAME',
  'SOUL_SYMBOL'
].forEach(i => {
  if (!process.env[i]) {
    throw new Error(
        `Environment variable ${i} is not defined.  Please add it to the ".env" file.`
    )
  }
});

const {
   MINT_PASS_NAME,
   MINT_PASS_SYMBOL,
   MINT_PASS_BASE_TOKEN_URI,
   MINT_PASS_TOTAL_BIDS_LIMIT,
   MINT_PASS_MINIMUM_BID_AMOUNT,
   MINT_PASS_START,
   MINT_PASS_AUCTION_DURATION,
   SUBSCRIPTION_ID,
   VRF_COORDINATOR_ADDRESS,
   LINK_TOKEN_ADDRESS,
   VRF_KEY_HASH,
   SCION_NAME,
   SCION_SYMBOL,
   SOUL_NAME,
   SOUL_SYMBOL
  } = process.env;

export default {
  MINT_PASS_NAME,
  MINT_PASS_SYMBOL,
  MINT_PASS_BASE_TOKEN_URI,
  MINT_PASS_TOTAL_BIDS_LIMIT,
  MINT_PASS_MINIMUM_BID_AMOUNT,
  MINT_PASS_START,
  MINT_PASS_AUCTION_DURATION,
  SUBSCRIPTION_ID,
  VRF_COORDINATOR_ADDRESS,
  LINK_TOKEN_ADDRESS,
  VRF_KEY_HASH,
  SCION_NAME,
  SCION_SYMBOL,
  SOUL_NAME,
  SOUL_SYMBOL
}