#!/bin/bash


ETH_RPC='http://localhost:8545'
MIN_PRIO_FEE_GWEI=1  # minimum priority fee in gwei
DEP_CHECK='auto'     # set this to 'curl' or 'wget' to disable dependencies check 


help=\
'Calculate the next block gas price using the latest block base fee and gas usage.\n'\
'Requires jq and either curl or wget (auto detected).\n\n'\
'Usage:\n'\
'  ./gasnext.sh [-dw] [-r rpc_url] [-p minimum_priority_fee]\n\n'\
'Options:\n'\
'  -h --help          Show help.\n'\
'  -d                 Output comma-separated Base Fee and Priority Fee.\n'\
'  -w                 Output in wei.\n'\
"  -r <rpc_url>       RPC url (default: ${ETH_RPC}).\n"\
"  -p <min_prio_fee>  Minimum priority fee in gwei to apply to output (default: $MIN_PRIO_FEE_GWEI gwei).\n"


details=''
wei_out=''
gwei=1000000000
while getopts ":hr:p:dw-:" opt; do
    case $opt in
        d) details=1 ;;
        w) wei_out=1 ;;
        r) ETH_RPC="$OPTARG" ;;
        p) MIN_PRIO_FEE_GWEI="$OPTARG" ;;
        :)   { echo "Option -$OPTARG requires an argument." >&2 ; echo -e "\n$help"; exit 1; } ;;
        \?)  { echo "Invalid option: -$OPTARG" >&2 ; echo -e "\n$help"; exit 1; } ;;
        h|-) { echo -e "$help"; exit 0; } ;;
    esac
done


# check dependencies: jq and curl/wget
if [ "$DEP_CHECK" = curl ]; then
    http_cmd='curl'
elif [ "$DEP_CHECK" = wget ]; then
    http_cmd='wget'
else
    http_cmd='curl'  # default to curl
    command -v jq >/dev/null 2>&1   || { echo >&2 "error: jq is not installed"; exit 1; }
    command -v curl >/dev/null 2>&1 || http_cmd='wget'
fi


# get lastest block data: base fee, gas target and gas used
eth_query='{"method":"eth_getBlockByNumber","params":["latest",true],"id":1,"jsonrpc":"2.0"}'
if [ "$http_cmd" = curl ]; then
    block=$(curl -Ls -d "$eth_query" -H "Content-Type:application/json" "$ETH_RPC")
else
    block=$(wget -q --post-data "$eth_query" --header "Content-Type:application/json" -O- "$ETH_RPC")
fi
block_data=$(echo "$block" | jq -r '.result | "\(.baseFeePerGas),\(.gasLimit),\(.gasUsed)"')
base_fee_hex="${block_data%%,*}"
base_fee=$(printf '%u' $base_fee_hex)
block_data="${block_data#*,}"
gas_target=$(( $(printf '%u' "${block_data%,*}") / 2 ))
gas_used_delta=$(( $(printf '%u' "${block_data#*,}") - $gas_target ))


# calculate next block base fee using latest block base fee, gas target and gas used
if [ "$gas_used_delta" = 0 ]; then
    new_base_fee="$base_fee"
else
    x=$(( $base_fee * ${gas_used_delta#-} ))
    y=$(( $x / $gas_target ))
    fee_delta=$(( $y / 8 ))
    if [ "$gas_used_delta" -gt 0 ]; then
        new_base_fee=$(( $base_fee + $fee_delta ))
    else
        new_base_fee=$(( $base_fee - $fee_delta ))
    fi
fi


# get the minimum priority fee paid in latest block
# which is the minimum total gas price minus the base fee
# txs with 0 priority fee are excluded
gas_price_min=$(echo "$block" | jq -r '.result.transactions[].gasPrice' | grep -v $base_fee_hex | sort -g | head -1)
prio_fee=$(( $(printf '%u' $gas_price_min) - $base_fee ))
# apply minimum priority fee
[ "$prio_fee" -lt $(( $MIN_PRIO_FEE_GWEI * $gwei )) ] && prio_fee=$(( $MIN_PRIO_FEE_GWEI * $gwei ))


# print result
if [ -z "$details" ] && [ -z "$wei_out" ]; then
    echo $(( $(( $new_base_fee + $prio_fee )) / $gwei ))
elif [ "$details" ] && [ "$wei_out" ]; then
    echo "${new_base_fee},${prio_fee}"
elif [ "$details" ]; then
    echo $(( $new_base_fee / $gwei )),$(( $prio_fee / $gwei ))
else
    echo $(( $new_base_fee + $prio_fee ))
fi
