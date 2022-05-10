# gasnext.sh

Bash script to get the next block gas price directly from an Ethereum node.

When running a local Ethereum node it gets the exact next block gas price in a fraction of a second and without relying on any third party.

It also works with any remote RPC like Infura but it will be slower.

## Requirements  
- `jq`  
- `curl` or `wget` (auto detected)
- `bash` with 64 bit integer arithmetic
- `sort` with `-g` option

## Usage
  `./gasnext.sh [-dw] [-r rpc_url] [-p minimum_priority_fee]`

**Options:**
```
-h --help          Show help.
-d                 Output comma-separated Base Fee and Priority Fee.
-w                 Output in wei.
-r <rpc_url>       RPC url (default: http://localhost:8545).
-p <min_prio_fee>  Minimum priority fee in gwei to apply to output (default: 1 gwei).
```

The script makes one RPC call `eth_getBlockByNumber` to get the latest block information and use the base fee and gas usage to calculate the next block base fee.

The priority fee is estimated by taking the lowest priority fee paid in the latest block. This could be inaccurate if there are transactions paying too low fees. By default a minimum of 1 gwei is applied to the returned value.


## Configuration
The default RPC url is set to `http://localhost:8545` and can be edited by changing `ETH_RPC` in the top of the script.

`MIN_PRIO_FEE_GWEI` and `DEP_CHECK` can also be edited to change the minimum priority fee and to disable the dependencies check.


