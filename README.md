# nsfailover

<!-- badges/ -->
[![Build Status](https://secure.travis-ci.org/kvz/nsfailover.png?branch=master)](http://travis-ci.org/kvz/nsfailover "Check this project's build status on TravisCI")
[![Gittip donate button](http://img.shields.io/gittip/kvz.png)](https://www.gittip.com/kvz/ "Sponsor the development of nsfailover via Gittip")
[![Flattr donate button](http://img.shields.io/flattr/donate.png?color=yellow)](https://flattr.com/submit/auto?user_id=kvz&url=https://github.com/kvz/nsfailover&title=nsfailover&language=&tags=github&category=software "Sponsor the development of nsfailover via Flattr")
[![PayPayl donate button](http://img.shields.io/paypal/donate.png?color=yellow)](https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=kevin%40vanzonneveld%2enet&lc=NL&item_name=Open%20source%20donation%20to%20Kevin%20van%20Zonneveld&currency_code=USD&bn=PP-DonationsBF%3abtn_donate_SM%2egif%3aNonHosted "Sponsor the development of nsfailover via Paypal")
[![BitCoin donate button](http://img.shields.io/bitcoin/donate.png?color=yellow)](https://coinbase.com/checkouts/19BtCjLCboRgTAXiaEvnvkdoRyjd843Dg2 "Sponsor the development of nsfailover via BitCoin")
<!-- /badges -->

Together with EC2 Premium support I've established that:

> "Unfortunately the Linux DNS resolver doesn't seem to have direct
support for detecting and doing failovers for DNS servers so you 
may need to write your own solution as you mentioned. " - Amazon Web Services Jan 22, 2013 01:13 AM PST

Read a [longer introduction on my blog](http://kvz.io/blog/2013/03/27/poormans-way-to-decent-dns-failover/)
which was [featured on Hacker News](https://news.ycombinator.com/item?id=5450140). 

This simple program makes DNS outages suck less.

## nsfailover

Every minute (or whatever), `nsfailover.sh` checks to see if the primary configured nameserver
can resolve `google.com`.
If it cannot, it writes the secondary, or even tertary server to 
function as the primary server in `/etc/resolv.conf`.

This way, requests are stalled for max a minute, and then all following requests
are fast, even if the primary stays down.

## Install

```bash
sudo curl -q https://raw.github.com/kvz/nsfailover/master/nsfailover.sh -o /usr/bin/nsfailover.sh && sudo chmod +x $_
```

## Example

```bash
crontab -e
* * * * * NS_1=172.16.0.23 nsfailover.sh 2>&1 |logger -t cron-nsfailover
```

## Config

**nsfailover** is configured through environment variables.
Here they are with their defaults:


```bash
LOG_LEVEL="6" # 7 = debug, 0 = emergency
NS_1="" # Primary Nameserver (172.16.0.23 for Amazon EC2). You need to set this yourself
NS_2="8.8.8.8" # Secundary Nameserver: Google
NS_3="4.2.2.2" # Tertiary Nameserver: Level3
NS_ATTEMPTS="1" # http://linux.die.net/man/5/resolv.conf
NS_ENABLE="no" # Set to no to disable
NS_FILE="/etc/resolv.conf" # Where to write resolving conf
NS_SEARCH="" # Domain to search hosts in (compute-1.internal for Amazon EC2)
NS_TESTDOMAIN="google.com" # Use this to determine if NS is healthy
NS_TIMEOUT="3" # http://linux.die.net/man/5/resolv.conf
NS_WRITEPROTECT="no" # Use this to write-protect /etc/resolv.conf
```

You can use environment variables in many ways: at the top of a script or crontab, 
`export` from another script, or pass them straight to the program:

```bash
NS_ENABLE="no" ./nsfailover.sh # <-- silly, but works :)
```

## Notes

**nsfailover**

- only rewrites `/etc/resolv.conf` if it has changes
- makes a backup to e.g. `/etc/resolv.conf.bak-20130327114321`
- needs to run as `root`

## Tips

- Prefix your cronjob with `timeout -s 9 50s` so there can never be an overlap. 
More tips in my [Lock your Cronjobs](http://kvz.io/blog/2012/12/31/lock-your-cronjobs/) article.

## Versioning

This project implements the Semantic Versioning guidelines.

Releases will be numbered with the following format:

`<major>.<minor>.<patch>`

And constructed with the following guidelines:

* Breaking backward compatibility bumps the major (and resets the minor and patch)
* New additions without breaking backward compatibility bumps the minor (and resets the patch)
* Bug fixes and misc changes bumps the patch


For more information on SemVer, please visit [http://semver.org](http://semver.org).

## License

Copyright (c) 2013 Kevin van Zonneveld, [http://kvz.io](http://kvz.io)  
Licensed under MIT: [http://kvz.io/licenses/LICENSE-MIT](http://kvz.io/licenses/LICENSE-MIT)
