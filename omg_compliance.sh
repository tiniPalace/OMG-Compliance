#!/bin/bash

# Setting required variables

source .omgrc
tempPgpFn="temp_pgp.txt"
tempMirFn="temp_mirrors.txt"
tempCanFn="temp_canary.txt"
tempKeyringFile="temp_keyring"
lastURLFn="lasturl.txt"
pgpImported=0

nonCompliance=0     # Counts compliance issues


###########################################
## Functions
###########################################

# First argument is the name of the file with the signature.
function VerifySignature () {
    local verifiedSig=0
    local signedFile=$1
    if [[ $useTemporaryKeyring -eq 1 && $checkWithPrivateKeyring -ne 1 ]]; then
        verifiedSig=$(gpg --homedir ./ --no-default-keyring --keyring $tempKeyringFile --verify $signedFile 2>&1 | sed -n -E "/Good signature/p" | wc -l)
    else
        verifiedSig=$(gpg --verify $signedFile | sed -n -E "/Good signature/p" | wc -l)
    fi

    if [[ $verifiedSig -eq 1 ]]; then
        [[ $verbose -eq 1 ]] && echo -e "\033[1;96m[OK]\033[0m"
        return 0
    else
        [[ $verbose -eq 1 ]] && echo -e "\033[1;91m[ X]\033[0m:\tWas not able to verify the signature of $signedFile";
        nonCompliance=$((nonCompliance+1))
        return 1
    fi
}
# First argument is the filename on the remote server
# Second argument is the filename where the output is saved
function VerifyResponse () {
    local remoteFn=$1
    local outFn=$2
    [[ $verbose -eq 1 ]] && echo -n -e "Response code compliance:\t"

    response=$(curl -s -x socks5h://localhost:$portNumber -o "./$outFn" -w "%{content_type}, %{http_code}" "$url/$remoteFn")

    local ctype=$(echo $response | sed -E "s/^([a-z]+\/[a-z]+).*$/\1/")
    local httpCode=$(echo $response | sed -E "s/.*, ([0-9]{3})$/\1/")

    if [[ $ctype == $omgContentType && $httpCode -eq $omgHttpCode ]]; then
        [[ $verbose -eq 1 ]] && echo -e "\033[1;96m[OK]\033[0m"
        correctResponse=1
    else
        [[ $verbose -eq 1 ]] && echo -e "\033[1;91m[ X]\033[0m:\t$url/$remoteFn returned $response"
        nonCompliance=$((nonCompliance+1))
    fi
}
# Exit with usage message.
function ErrorExit () {
    echo -e "ERROR: '${0##*/}' needs an argument containing a valid url on the form\n:~$ ${0##*/} [-cnlespk] http[s]://[xxx.]xxxxxxxxx.xxxx" >&2
    exit 1
}


###########################################
## Parsing arguments
###########################################

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--cache-URL)
            cacheURL=1
            shift
            ;;
        -n|--no-double-check)
            doubleCheckBlockchain=0
            shift
            ;;
        -l|--non-strict|--lazy)
            strict=0
            shift
            ;;
        -e|--clearnet-explorer)
            anonymousBitcoinHashVerification=0
            shift
            ;;
        -s|-q|--quiet|--silent)
            verbose=0
            shift
            ;;
        -k|--private-keyring)
            useTemporaryKeyring=0
            shift
            ;;
        -p|--port)
            portNumber="$2"
            shift
            shift
            ;;
        -*|--*)
            echo "ERROR: Unknown option $1"
            ErrorExit
            ;;
        *)
            POS_ARGS+=("$1")
            shift
            ;;
    esac
done
set -- "${POS_ARGS[@]}"


###########################################
## Validating URL Format
###########################################

# Find last argument
url=${@: -1}
if [[ $# -eq 0 && -e $lastURLFn ]]; then
    [[ $verbose -eq 1 ]] && echo -e "No URL argument found, loading last used URL."
    url=$(cat $lastURLFn)
elif [[ $# -eq 0 ]]; then
    ErrorExit
fi

# Splitting scheme and url
domain=$(echo $url | sed -n -E "s/^([a-z]*[:]+[\/]+(([a-z0-9A-Z\-]*\.)+[a-z0-9A-Z\-]*)|(([a-z0-9A-Z\-]*\.)+[a-z0-9A-Z\-]*))(\/.*)?$/\2\4/p")
scheme=$(echo $url | sed -n -E "s/^([a-z]+)[:]+\/[\/]+[a-zA-Z0-9\.\-]*$/\1/p")

if [[ $# -gt 1 || $domain == "" ]]; then
    ErrorExit
elif [[ $domain =~ ^[a-z0-9]{56}\.onion$ ]]; then
    scheme="http"
elif [[ $scheme == "" && $domain != "" ]]; then
    [[ $verbose -eq 1 ]] && echo "Warning: no protocol attached: assuming https."
    scheme="https"
elif [[ $scheme != "https" ]]; then
    echo -e -n "Warning: non-https protocol detected on non-onion domain.\nYour connection may be vulnerable to a man-in-the-middle attack.\nAre you sure you want to proceed? [y/n] "
    read ans
    if [[ ! $ans =~ [yY] ]]; then
        exit 0
    fi
fi

url="$scheme://$domain"
[[ $cacheURL -eq 1 ]] && echo $url > $lastURLFn


###########################################
## pgp.txt
###########################################

[[ $verbose -eq 1 ]] && echo -e "\n#############################################"
[[ $verbose -eq 1 ]] && echo "Checking /pgp.txt"
[[ $verbose -eq 1 ]] && echo "---------------------------------------------"

# Response codes ---------------------------------------------------

correctResponse=0
VerifyResponse pgp.txt $tempPgpFn

# PGP Key processing -----------------------------------------------

keyNum=0
if [[ $correctResponse -eq 1 ]]; then
    [[ $verbose -eq 1 ]] && echo -n -e "Contains PGP keys:\t\t"
    # Get number of pgp keys in returned text
    keyNum=$(gpg --show-keys $tempPgpFn | sed -n "/pub/p" | wc -l)
    if [[ $keyNum -gt 0 ]]; then
        [[ $verbose -eq 1 ]] && echo -e "\033[1;96m[OK]\033[0m"
        [[ $verbose -eq 1 ]] && echo -n -e "Imported $keyNum PGP keys "
        # Import keys into keyring
        if [[ $useTemporaryKeyring -eq 1 ]]; then
            gpg --homedir ./ --no-default-keyring --keyring $tempKeyringFile --import $tempPgpFn &>/dev/null
            [[ $verbose -eq 1 ]] && echo "to a temporary keyring."
        else
            gpg --import $tempPgpFn &>/dev/null
            [[ $verbose -eq 1 ]] && echo "to your private keyring."
        fi
        pgpImported=1
    else
        [[ $verbose -eq 1 ]] && echo -e "\033[1;91m[ X]\033[0m:\t$url/pgp.txt does not seem to contain any pgp keys."
        nonCompliance=$((nonCompliance+1))
    fi
fi


###########################################
## mirrors.txt
###########################################

[[ $verbose -eq 1 ]] && echo -e "\nChecking /mirrors.txt"
[[ $verbose -eq 1 ]] && echo "---------------------------------------------"

# Response codes ---------------------------------------------------

correctResponse=0
VerifyResponse mirrors.txt $tempMirFn

# Link processing --------------------------------------------------

if [[ $correctResponse -eq 1 ]]; then
    [[ $verbose -eq 1 ]] && echo -n -e "Contains compliant links:\t"

    numLinks=0
    additionalLinks=0
    if [[ $correctResponse -eq 1 ]]; then
        # Find number of links in mirrors.txt
        numLinks=$(cat ./$tempMirFn | sed -n -E "/^http[s]?:\/\/[a-zA-Z0-9\-]+\.[a-zA-Z0-9\.\-]+$/p" | wc -l)
        if [[ $strict -ne 1 ]]; then
            additionalLinks=$(cat ./$tempMirFn | sed -n -E "/^([h]+[t]+[p]+[s]*[:]+\/[\/]+[a-zA-Z0-9\.\-]+|[a-zA-Z0-9\-]+\.[a-zA-Z0-9\.\-]+)$/p" | wc -l)
        fi
    fi
    if [[ $numLinks -gt 0 ]]; then
        [[ $verbose -eq 1 ]] && echo -e "\033[1;96m[OK]\033[0m: $numLinks"
    elif [[ $additionalLinks -gt 0 ]]; then
        [[ $verbose -eq 1 ]] && echo -e "\033[1;93m[--]\033[0m: Links not correctly formatted."
    else
        [[ $verbose -eq 1 ]] && echo -e "\033[1;91m[ X]\033[0m"
        nonCompliance=$((nonCompliance+1))
    fi

    # Signature verification -------------------------------------------

    if [[ $pgpImported -eq 1 ]]; then
        [[ $verbose -eq 1 ]] && echo -n -e "Consistent PGP signature:\t"

        VerifySignature $tempMirFn
    fi
fi


###########################################
## canary.txt
###########################################

[[ $verbose -eq 1 ]] && echo -e "\nChecking /canary.txt"
[[ $verbose -eq 1 ]] && echo "---------------------------------------------"

# Response codes ---------------------------------------------------

correctResponse=0
VerifyResponse canary.txt $tempCanFn

# String inclusion -------------------------------------------------

if [[ $correctResponse -eq 1 ]]; then
    [[ $verbose -eq 1 ]] && echo -n -e "Contains required strings:\t"
    containsString1=$(sed -n -E "/$requiredString/p" $tempCanFn | wc -l)
    containsString2=$(sed -n -E "/$updateString/p" $tempCanFn | wc -l)
    if [[ $containsString1 -gt 0 && $containsString2 -gt 0 ]]; then
        [[ $verbose -eq 1 ]] && echo -e "\033[1;96m[OK]\033[0m"
    else
        if [[ $strict -ne 1 ]]; then
            search_pattern1=$(echo $requiredString | sed -e "s/\./\[\.\]\*/g")
            search_pattern2=$(echo $updateString | sed -e "s/\./\[\.\]\*/g")
            containsLazyString1=$(sed -n -E "s/^.*($search_pattern1).*$/\1/pi" $tempCanFn | wc -l)
            containsLazyString2=$(sed -n -E "s/^.*($search_pattern2).*$/\1/pi" $tempCanFn | wc -l)
        fi

        if [[ $containsLazyString1 -gt 0 && $containsLazyString2 -gt 0 ]]; then
            [[ $verbose -eq 1 ]] && echo -e "\033[1;93m[--]\033[0m: Strings are not correctly formatted."
        else
            if [[ $verbose -eq 1 ]]; then
                echo -e "\033[1;91m[ X]\033[0m: Missing strings"
            fi
            nonCompliance=$((nonCompliance+1))
        fi
        [[ $verbose -eq 1 && $containsString1 -eq 0 ]] && echo -e "\t\"$requiredString\""
        [[ $verbose -eq 1 && $containsString2 -eq 0 ]] && echo -e "\t\"$updateString\""
    fi

# Checking date ----------------------------------------------------

    [[ $verbose -eq 1 ]] && echo -n -e "Contains date:\t\t\t"
    includedDate=$(sed -n -E "s/^.*([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/p" $tempCanFn)
    nonStrictDate=0
    # Try more date formats of not strict
    if [[ $includedDate == "" && $strict -ne 1 ]]; then
        includedDate=$(sed -n -E "s/^.* ([1-3]?[1-9]+)[a-z]*( [a-zA-Z]* [0-9]{4}).*/\1\2/p" $tempCanFn)
        nonStrictDate=1
    fi
    if [[ $includedDate != "" ]]; then
        if [[ $nonStrictDate -eq 0 ]]; then
            [[ $verbose -eq 1 ]] && echo -e "\033[1;96m[OK]\033[0m"
        else
            [[ $verbose -eq 1 ]] && echo -e "\033[1;93m[--]\033[0m: Date '$includedDate' is not correctly formatted."
        fi

        [[ $verbose -eq 1 ]] && echo -n -e "Date within time-limit:\t\t"
        dateLimit=$(date --date="$includedDate +$dayLimit days" "+%s")
        currentTime=$(date "+%s")

        if [[ $dateLimit -ge $currentTime ]]; then
            [[ $verbose -eq 1 ]] && echo -e "\033[1;96m[OK]\033[0m"
        else
            dateExpired=$(date --date="$includedDate +$dayLimit days" "+%Y-%m-%d")
            [[ $verbose -eq 1 ]] && echo -e "\033[1;91m[ X]\033[0m:\tCanary expired on $dateExpired"
            nonCompliance=$((nonCompliance+1))
        fi

    else
        [[ $verbose -eq 1 ]] && echo -e "\033[1;91m[ X]\033[0m"
        nonCompliance=$((nonCompliance+1))
    fi

# Bitcoin hash verification ----------------------------------------

    [[ $verbose -eq 1 ]] && echo -n -e "Valid bitcoin-block included:\t"

    includedHash=$(sed -n -E "/^[A-Fa-f0-9]{64}$/p" $tempCanFn)

    # Search hash on blockstream.com's onion site, or on blockchain.info
    if [[ $anonymousBitcoinHashVerification -eq 1 ]]; then
        blockchain_url="http://explorerzydxu5ecjrkwceayqybizmpjjznk5izmitf2modhcusuqlid.onion/api/block/"
        hashTime=$(curl -s -x socks5h://localhost:$portNumber $blockchain_url$includedHash | sed -n -E "s/^.*\"timestamp\":[ ]*([0-9]*),.*$/\1/p")
    else
        blockchain_url="https://blockchain.info/rawblock/"
        hashTime=$(curl -s $blockchain_url$includedHash | sed -n -E "s/.*\"time\":[ ]*([0-9]*),.*/\1/p")
    fi

    if [[ $hashTime != "" ]]; then
        [[ $verbose -eq 1 ]] && echo -e "\033[1;96m[OK]\033[0m"
    else
        [[ $verbose -eq 1 ]] && echo -e "\033[1;91m[ X]\033[0m:\tThe hash $includedHash could not be found on $blockchain_url"
        nonCompliance=$((nonCompliance+1))
    fi

    # Double-check that the hash time is the same for independent blockchain explorer.
    if [[ $hashTime != "" && $doubleCheckBlockchain -eq 1 ]]; then
        [[ $verbose -eq 1 ]] && echo -n -e "Double checking blockchain:\t"
        blockchain_check_url="http://btcexpz7xlwrqknqw6p3bok6shf73qtkd6zxct4x4qta2ktvh7ntprad.onion/api/block/"
        checkHashTime=$(curl -s -x socks5h://localhost:$portNumber $blockchain_check_url$includedHash | sed -n -E "s/^.*\"time\":[ ]*([0-9]*),.*$/\1/p")
        interval=5
        timeDiff=$(( hashTime - checkHashTime ))
        if [[ $timeDiff -gt -$interval && $timeDiff -lt $interval ]]; then
            [[ $verbose -eq 1 ]] && echo -e "\033[1;96m[OK]\033[0m"
        else
            [[ $verbose -eq 1 ]] && echo -e "\033[1;91m[ X]\033[0m:\tThere was a $timeDiff s time difference between the times returned from\n: $blockchain_url,\n: $blockchain_check_url,\nfor hash\n: $includedHash,\n which is outside the allowed interval of $interval seconds."
            nonCompliance=$((nonCompliance+1))
        fi
    fi

    if [[ $hashTime != "" ]]; then
        # Check if hash is within time-limit
        [[ $verbose -eq 1 ]] && echo -n -e "Hash is within time-limit:\t"

        hashDate=$(date --date="@$hashTime" "+%Y-%m-%d")
        hashLimitTime=$(date --date="$hashDate +$dayLimit days" "+%s")
        hashLimitDate=$(date --date="$hashDate +$dayLimit days" "+%Y-%m-%d")
        [[ -v currentTime ]] || currentTime=$(date "+%s")

        if [[ $hashLimitTime -ge $currentTime ]]; then
            [[ $verbose -eq 1 ]] && echo -e "\033[1;96m[OK]\033[0m"
        else
            [[ $verbose -eq 1 ]] && echo -e "\033[1;91m[ X]\033[0m:\tThe hash expired on $hashLimitDate.";
            nonCompliance=$((nonCompliance+1))
        fi
    fi

# Signature verification -------------------------------------------

    if [[ $pgpImported -eq 1 ]]; then
        [[ $verbose -eq 1 ]] && echo -n -e "Consistent PGP signature:\t"

        VerifySignature $tempCanFn
    fi
fi

###########################################
## Checking optional files
###########################################

optionalFn="related.txt"
outFn="temp_related.txt"

if [[ $verbose -eq 1 ]]; then
    echo -e "\nChecking optional file /$optionalFn"
    echo "---------------------------------------------"
    VerifyResponse $optionalFn $outFn
    rm $outFn &> /dev/null
fi

###########################################
## Temp file cleanup
###########################################

rm ./$tempPgpFn &> /dev/null
rm ./$tempMirFn &> /dev/null
rm ./$tempCanFn &> /dev/null

if [[ $useTemporaryKeyring -eq 1 ]]; then
    rm ./$tempKeyringFile* &> /dev/null
    rm ./random_seed &> /dev/null
    rm ./trustdb.gpg &> /dev/null
fi


###########################################
## Final result
###########################################

if [[ $verbose -eq 1 ]]; then
    echo -e "#############################################\n"
    echo -n -e "The site $url\nis OMG compliant:\t\t"
else
    echo -n -e "OMG compliance:\t"
fi

if [[ $nonCompliance -eq 0 ]]; then
    echo -e "\033[1;96m[OK]\033[0m"
else
    if [[ $nonCompliance -eq 1 ]]; then
        echo -e "\033[1;91m[ X]\033[0m:\tThere was $nonCompliance compliancy issue."
    else
        echo -e "\033[1;91m[ X]\033[0m:\tThere were $nonCompliance compliancy issues."
    fi
fi

[[ $verbose -eq 1 ]] && echo " "
