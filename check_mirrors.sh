#!/bin/bash

origMirFn="original_mirrors.txt"
linkedMirFn="linked_mirrors.txt"
origPgpFn="original_pgp.txt"
linkedPgpFn="linked_pgp.txt"
mirFn="mirrors.txt"
pgpFn="pgp.txt"
timeLimit=3

source .omgrc

function downloadFile () {
    local url=$1
    local outFn=$2
    response=$(curl -s -x socks5h://localhost:$portNumber --connect-timeout $timeLimit -o "./$outFn" -w "%{content_type}, %{http_code}" "$url")

    ctype=$(echo $response | sed -E "s/^([a-z\/]*)[;]? .*$/\1/")
    httpCode=$(echo $response | sed -E "s/.*, ([0-9]{3})$/\1/")

    if [[ $ctype == $omgContentType && $httpCode -eq $omgHttpCode ]]; then
        echo "success"
    else
        echo "failed"
    fi
}

# Download links

###########################################
## Validating URL Format
###########################################

url="$1"
if [[ $# != 1 || ! $url =~ http[s]?://[a-z0-9]*\.?[a-z0-9\-]+\.[a-z]+$ ]]; then
    echo -e "ERROR: '${0##*/}' needs a single argument containing a valid url on the form\n\n http[s]://[xxx.]xxxxxxxxx.xxxx" >&2
    exit 1
fi

# Downloading original files.

[[ $verbose -eq 1 ]] && echo -e "Downloading files $origMirFn and $origPgpFn.."

mirRet=$(downloadFile "$url/$mirFn" $origMirFn)
pgpRet=$(downloadFile "$url/$pgpFn" $origPgpFn)
if [[ $mirRet != "success" || $pgpRet != "success" ]]; then
    echo "Failed to download files from $url."
    rm $origMirFn; rm $origPgpFn
    exit 1
fi

# Extract the urls from the mirror file and check their formatting.

links=$(cat ./$origMirFn | sed -n -E "/^http[s]?:\/\//p")
links_array=()

[[ $verbose -eq 1 ]] && echo "Found urls:"

for link in $links
do
    # Separate the protocol and the domain name from the url
    protocol="${link%%/*}//"
    domain="${link#*//}"
    # Remove any trailing path from the url
    domain="${domain%%/*}"
    # Remove any port-number specification from the url
    domain="${domain%%:*}"

    # Check domain format and skip current domain when building url array
    if [[ ! $domain =~ ^([A-Za-z0-9]*\.)?[A-Za-z0-9]*\.[A-Za-z0-9]*$ ]]; then
        echo -e "WARNING: $link does not have a correctly formatted domain and will be ignored"
    else
        if [[ "$protocol$domain" != $url ]]; then
            [[ $verbose -eq 1 ]] &&  echo -e -n "$protocol$domain, "
            links_array+=( "${protocol}${domain}" )
        fi
    fi
done

[[ $verbose -eq 1 ]] && echo -e "\n\nChecking that these sites contain $mirFn and $pgpFn that mirror the files on $url perfectly:"

# Now go through all the links in the mirror file and check that they contain
# the same mirror.txt and pgp.txt file.
for link in ${links_array[@]}
do
    mirRet=$(downloadFile "$link/$mirFn" $linkedMirFn)
    pgpRet=$(downloadFile "$link/$pgpFn" $linkedPgpFn)

    mirDiff="initialized"; pgpDiff="initialized"
    if [[ $mirRet == "success" && $pgpRet == "success" ]]; then
        mirDiff=$(diff -q $origMirFn $linkedMirFn)
        pgpDiff=$(diff -q $origPgpFn $linkedPgpFn)
    fi

    if [[ $mirDiff == "" && $pgpDiff == "" ]]; then
        echo -e -n "\033[1;96m[OK]\033[0m\t"
    else
        echo -e -n "\033[1;91m[ X]\033[0m\t"
    fi
    echo "$link"
done

# Clean up temporary files
[[ $verbose -eq 1 ]] && echo -e "\nRemoving downloaded files."

rm $origMirFn
rm $origPgpFn
rm $linkedMirFn
rm $linkedPgpFn
