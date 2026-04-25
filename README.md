# Demo Introduction

**This is a demo for our project, including reference contract and a frontend.**

## Conntract Documentation

```shell
├── foundry.lock
├── foundry.toml
├── frontend
├── icon.png
├── lib
│   ├── forge-std
│   └── openzeppelin-contracts
├── script
│   └── IssuerVerifier.s.sol # Example Usage, you could modify  the params in this script
├── src
│   ├── BBSMath.sol # BBS signature scheme related math functions
│   ├── BBSVerifier.sol # Verifier contract
│   └── IssuerVerifier.sol # Example Usage, intergrate the Issuer and Verifier contract together
```

### Install

```shell
forge install
```

### Stucture

### Build

```shell
forge build
```

### Test

```shell
forge test
```

### Format

```shell
forge fmt
```

### Gas Snapshots

```shell
forge snapshot
```

### Deploy

```shell
forge script script/IssuerVerifier.s.sol:DeployIssuerVerifier --rpc-url $RPC_URL --private-key $PRIVATE_KEY --chain-id $CHAIN_ID --broadcast
```

### Verify and Mint （Scrirpt）

Set the address of `IssuerVerifier` [here](./script/Interact.s.sol) and run the script:

```shell
forge script script/Interact.s.sol:InteractScript --rpc-url $RPC_URL --private-key $PRIVATE_KEY --chain-id $CHAIN_ID --broadcast
```

### Some cast function call

1. Call stashNullifier

```shell
# gen the nullifier N
N_HASH=$(cast keccak $(cast abi-encode "f(address,uint256)" "0x1234000000000000000000000000000000000000" 192837465))
# call stashNullifier
cast send $ISSUER_VERIFIER "stashNullifier(bytes32)" $N_HASH --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

2. Call on-chain status

```shell
# Query the required constraints for the credential
cast call $ISSUER_VERIFIER "readConstraint()(uint256[])" --rpc-url $RPC_URL

# Query the Nullifier existence
cast call $ISSUER_VERIFIER "keyExist(bytes32)(bool)" $N_HASH --rpc-url $RPC_URL

# Query if a user already has the token
cast call $ISSUER_VERIFIER "hasToken(address)(bool)" $TARGET_ADDRESS --rpc-url $RPC_URL

# Query the ctx value in the contract
cast call $ISSUER_VERIFIER "ctx()(bytes32)" --rpc-url $RPC_URL

# Query the tokenURI value in the contract
cast call $ISSUER_VERIFIER "tokenURI(uint256)(string)" $TOKENID --rpc-url $RPC_URL
```

3. Deployer methods

```shell
# deployer burn the tokens
cast send $ISSUER_VERIFIER "burn(uint256)" $TOKENID --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

4. Delete the nullifier

```shell
cast send $ISSUER_VERIFIER "removeNullifier(bytes32)" $N_HASH --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

5. Deploy could burn the tokens

```shell
cast send $ISSUER_VERIFIER "burn(uint256)" $TOKENID --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

## Frontend Documentation

*The frontend is under `frontend` folder*

### Install

```shell
cd frontend
npm install
```

### Run

```shell
npm run dev
```

## Sepolia Testnet Deployed Contract Address

```shell
== Logs ==
  BBSVerifier deployed at: 0xCE5e36a94C099f84248aEA51fdfa8C36fFcFCFc8
  IssuerVerifier deployed at: 0x8D9d696193C04E4d9CfeBD01f522862A88202AC3
==========================

Chain 11155111

Estimated gas price: 1.544771218 gwei

Estimated total gas used for script: 6287846

Estimated amount required: 0.009713283524016428 ETH

==========================

##### sepolia
✅  [Success] Hash: 0x705671122f5a3d73b75de8198101fbd6c545a5124786fc9168acf3216057fcc3
Contract Address: 0xCE5e36a94C099f84248aEA51fdfa8C36fFcFCFc8
Block: 10728264
Paid: 0.001254746881012816 ETH (1631128 gas * 0.769251022 gwei)

##### sepolia
✅  [Success] Hash: 0x6bfd237d115d7f161d6c7a6270763d7ed171e39e19e3a9c51d575e6c35f719ef
Contract Address: 0x8D9d696193C04E4d9CfeBD01f522862A88202AC3
Block: 10728265
Paid: 0.002773569281864544 ETH (3205677 gas * 0.865205472 gwei)

✅ Sequence #1 on sepolia | Total Paid: 0.00402831616287736 ETH (4836805 gas * avg 0.817228247 gwei)
==========================
```
