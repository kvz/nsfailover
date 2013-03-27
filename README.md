# nsfailover

Makes it suck less when your resolving Nameserver is unreachable.

You can have many nameserver entries in your `/etc/resolv.conf`
but if your primary nameserver fails, there is no intelligent
failover mechanism.

E.g. every resolving request still goes by
the primary server, waits for a timeout, then tries (the first server again
depending on your `attempts` config, then) the second
nameserver. This can cause serious delays & even downtime if your
primary nameserver fails, and your app relies on resolving any domainname
to an IP that's not in your `/etc/hosts` file.

Although resolving nameservers are often redundant, downtime & unreachable
networks happen. At [Transloadit](http://transloadit.com) we rely on working
nameservers and Amazon's infamous `172.16.0.23` has been down for us
many times.

People suggest two solutions:

 - Use a virtual IP, loadbalance to multiple resolving servers
 - Use [dnrd](http://dnrd.sourceforge.net/), proxy to multiple resolving servers

Both just introduce more components that can go down (SPOFs). 
I want something as archaic and robust as it can be.

Together with EC2 Premium support we have established that:

> "Unfortunately the Linux DNS resolver doesn't seem to have direct
support for detecting and doing failovers for DNS servers so you 
may need to write your own solution as you mentioned. " - Amazon Web Services Jan 22, 2013 01:13 AM PST

So I've decided to do this with just crontab and bash.

Every minute, `nslookup.sh` checks to see if the primary configured nameserver
can resolve `google.com`, and writes that to `/etc/resolf.conf`.
If it cannot, it writes the secondary, or tertary server.
This way, requests are stalled for a minute, tops, and all following requests
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

`nsfailover.sh` is configured through environment variables.
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

## Notes

`nslookup.sh`:

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
Licensed under MIT: [http://kvz.mit-license.org](http://kvz.mit-license.org)



