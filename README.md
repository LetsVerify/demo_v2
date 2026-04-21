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
# Query the Nullifier existence
cast call $ISSUER_VERIFIER "keyExist(bytes32)(bool)" $N_HASH --rpc-url $RPC_URL

# Query if a user already has the token
cast call $ISSUER_VERIFIER "hasToken(address)(bool)" 0x1234000000000000000000000000000000000000 --rpc-url $RPC_URL

# Query the ctx value in the contract
cast call $ISSUER_VERIFIER "ctx()(bytes32)" --rpc-url $RPC_URL

# Query the tokenURI value in the contract
cast call $ISSUER_VERIFIER "tokenURI(uint256)(string)" $TOKENID --rpc-url $RPC_URL
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
BBSVerifier deployed at: 0x5FE6c32a55823Eb87f8e1b3C15cFf1dAdC90AB0D
IssuerVerifier deployed at: 0x69AF9718542D79ff47d2513C209F9F2D224c6Fa8
==========================
##### sepolia
✅  [Success] Hash: 0x212f63a1f428335a8e9f720656dc62feb8cd09c6ccea42637252347394393988
Contract Address: 0x5FE6c32a55823Eb87f8e1b3C15cFf1dAdC90AB0D
Block: 10672706
Paid: 0.00007007772665222 ETH (1631140 gas * 0.042962423 gwei)


##### sepolia
✅  [Success] Hash: 0x795e3b5b023f80a50a228d730cefb1656f582c0216ec2297bb4a966280ab0984
Contract Address: 0x69AF9718542D79ff47d2513C209F9F2D224c6Fa8
Block: 10672706
Paid: 0.000131285345527014 ETH (3055818 gas * 0.042962423 gwei)

✅ Sequence #1 on sepolia | Total Paid: 0.000201363072179234 ETH (4686958 gas * avg 0.042962423 gwei)
==========================
```
