#!/bin/bash

source .omgrc

url="https://check.torproject.org"

echo -e "Connecting to $url through the SOCKS5 protocol at port $portNumber..."

if [[ $(curl -s --proxy socks5://localhost:$portNumber $url) =~ 'Congratulations. This browser is configured to use Tor.' ]]; then
    echo "Connection successful. Tor seems to be working."
else
    echo -e "ERROR: Was not able the connect through the Tor network properly.\nOn Debian based systems you can download Tor with the command\n\n:~$ sudo apt install torbrowser-launcher\n"
fi
