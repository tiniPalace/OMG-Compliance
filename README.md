# OMG Compliance

This shell script implements a client verification that an onion site
adheres to the *"Onion Mirror Guidelines"*, which are defined in the *omg.txt*
file at [dark.fail](https://dark.fail/spec/omg.txt) (a copy of this file
can be found in this repository).


## Installation

#### Dependencies

You have to have Tor already installed such that *curl* can use the *SOCKS5*
proxy at `localhost:9050`. To check that this is properly setup, run the
**'check_tor.sh'** script. If you don't have Tor installed it can be installed
with your favourite package manager e.g. by running
```
sudo apt install torbrowser-launcher
```
on Debian-based systems such as Ubuntu.

The script also uses `gpg` in order to verify the PGP signed files. If you don't
have this installed, please run e.g.
```
sudo apt install gpg
```

#### Download instructions

To download this repository you can click the *"Code"* button in the upper right
corner and click *"Download ZIP"*, or, if you have `git` installed, you can simply
download it with
```
git clone https://github.com/tiniPalace/OMG-compliance
```
If you downloaded the *zip*-file, then go to your download directory and unzip it, e.g. with
```
unzip OMG-compliance-main.zip
```
which will create an `OMG-compliance-main` directory in your download folder. If you are
not able to run the scripts, you might need to change premissions to make them executable
by running
```
chmod 774 *.sh
```


## Use

To check if a site is OMG compliant, navigate to the directory where you downloaded this
repository, make sure that the file `omg_compliance.sh` has executable premissions and then
run
```
./omg_compliance.sh [website domain url e.g. https://dark.fail]
```
It is important that you include the `https://` in the url, or it willl throw an error.
Running `omg_compliance.sh` will check if the domain has included all the required files
in the [OMG Guidelines](https://dark.fail/spec/omg.txt) and whether these files contain
the required content.

The script carefully first checks that the returned response for each file is a plaintext
file before going on to attempt to verify the other requirements.

If the *verbose* setting is chosen, which it is by default, the script produces a detailed
report for each file over whether it exists and whether each OMG requirement is met. Finally
it counts the number of compliancy issues that it found. In the non-verbose version, only this last part is included in the output.

For the site to be completely OMG compliant, we also need to check if all links found in
`mirrors.txt` link to a site that contains the same content. You can check this by running
```
./check_mirrors.sh [website domain url e.g. https://dark.fail]
```
This script checks if the links all contain the same `pgp.txt` and `mirrors.txt` file.

## Settings

Variables that are meant to be changable by users are found in the file `.omgrc`.
Most of these variables are *flag* variables which are meant to be either `0` or `1`.
`1` means that the *flag* is turned on, while `0` means that it is off.

Below is a list of explanations of the different user-controlled variables

- `useTemporaryKeyring` (default=`1`): The script could either use your default `gpg` keyring and import the keys of the site into this, or it could create a temporary keyring in the same folder as the script in order to check pgp signatures.
- `checkWithPrivateKeyring` (default=`0`): If this is set to `1` then the script will use your private default keyring in order to verify pgp signatures regardsless of the status of the `useTemporaryKeyring`. This can be useful if you already have imported the keys of the site and want to check that the site still uses the same private key for signatures.
- `verbose` (default=`1`): If set to `0` the script will only print whether or not the site passed all the compliance tests. By default, the script prints a more detailed report.
- `anonymousBitcoinHashVerification` (default=`1`): In order to verify the bitcoin hash in the canary file, the script queries the *blockchain.info* API. If this flag is set to `1`, the query is sent through the Tor network, which provides security and anonymity. If set to `0`, the query is sent directly, which is significantly faster.
- `portNumber` (default=`9050`): This sets the port number where we connect to the Tor Socks5 proxy. By default this is set to `9050`, but if you have set up Tor in a non-default way, you will have to change this accordingly.
