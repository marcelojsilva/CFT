source .env

forge script --chain sepolia script/DeployC3Contracts.s.sol:DeployC3Contracts --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv
