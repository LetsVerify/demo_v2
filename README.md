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
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Deploy

```shell
$ forge script script/IssuerVerifier.s.sol:DeployIssuerVerifier --rpc-url $RPC_URL --private-key --private-key $PRIVATE_KEY --chain-id $CHAIN_ID --broadcast
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
# IssuerVerifier
✅  [Success] Hash: 0xf37900b4f52939514bc968967b5a9426fecd341bcc067598078959828e0ec262
Contract Address: 0x1C8d253077Ffc69C5161a68C3c52d86b78Db3F3B
Block: 10662704
Paid: 0.007096514998799646 ETH (3055878 gas * 2.322250757 gwei)

# BBSVerifier
✅  [Success] Hash: 0x11f94cf26d88c01bb0b336d4eb46ae3fe51735e21626e66fb9e0dc3e6c1ecb6a
Contract Address: 0xd3F1aed378b9b3577e22443aD0AC8aA15abd35f3
Block: 10662704
Paid: 0.003847772113034655 ETH (1656915 gas * 2.322250757 gwei)

✅ Sequence #1 on sepolia | Total Paid: 0.010944287111834301 ETH (4712793 gas * avg 2.322250757 gwei)
```
