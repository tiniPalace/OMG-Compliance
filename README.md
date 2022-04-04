# OMG Compliance Automation Kit

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
`unzip OMG-compliance-main.zip`,
which will create an `OMG-compliance-main` directory in your download folder. If you are
not able to run the scripts, you might need to change premissions to make them executable
by running `chmod 774 *.sh`.


## Use

### Single URL compliancy

To check if a site is OMG compliant, navigate to the directory where you downloaded this
repository and then
run
```
./omg_compliance.sh [-ceklnps] [website domain url e.g. https://dark.fail]
```
Running `omg_compliance.sh` will check if the domain has included all the required files
in the [OMG Guidelines](./omg.txt) and whether these files contain
the required content. The part about `[-ceiklnps]` are optional arguments whose functions are
detailed below.

The script carefully first checks that the returned response for each file is a plaintext
file before going on to attempt to verify the other requirements.

By default, the script produces a detailed
report for each file over whether it exists and whether each OMG requirement is met. Finally
it counts the number of compliancy issues that it found. In the non-verbose version, only this last part is included in the output.

### Mirror compliancy

For the site to be completely OMG compliant, we also need to check if all links found in
`mirrors.txt` link to a site that contains the same content. You can check this by running
```
./check_mirrors.sh [website domain url e.g. https://dark.fail]
```
This script checks if the links all contain the same `pgp.txt` and `mirrors.txt` file.

## Options

Options can be set to modify the behaviour of `omg_compliance.sh` by including these arguments
before the url, e.g.
```
./omg_compliance --non-strict https://tor.taxi
```
Below is a list of explanations of the different arguments

- `-c, --cache-url`  
Save URL to a file `lasturl.txt`. If the script is then run without a URL parameter, the url will be loaded from this file.
- `-e, --clearnet-explorer`  
Use the bitcoin blockchain explorer api on the clearnet at `https://blockchain.info/rawblock/`, instead of the hidden service at `http://explorerzydxu5ecjrkwceayqybizmpjjznk5izmitf2modhcusuqlid.onion/api/block/`.
- `-i, --import-keys`  
Import the keys found in `/pgp.txt` into your private keyring, which in most cases are located at `~/.gnupg/`.
- `-k, --private-keyring`  
Use the keys found in your private keyring to verify the signatures of the different *"omg files"*, instead of verifying them with the key found in `/pgp.txt`. Note that this only has any point to it if you don't use the `-i` option described above.
- `-l, --non-strict, --lazy`  
Allow for some fuzzyness in the verification of OMG criteria such as case in-sensitivity and optional punctuation in string matching, different date format and non-OMG sanctioned url specification in the `mirrors.txt` file.
- `-n, --no-double-check`  
This options prevents the script from taking the time to independently check that the time-value found from the blockchain explorer after searching for the hash found in `/canary.txt` is approximately equal to the one found when using a completely different blockchain explorer. This has the advantage of making the script faster.
- `-p <port number>, --port <port number>`  
Specify a different port number of the Tor SOCKS5 proxy. The standard is to use `localhost:9050`.
- `-s, --silent, -q, --quiet`
Turn off verbose mode and make the script only output whether the site is OMG compliant or not.
