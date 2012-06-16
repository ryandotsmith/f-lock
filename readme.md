# f-lock

Much like the whims of a wild river, unexpected events can cause internet services to fail in catastrophic ways. Civil engineers tame rivers, like the Mississippi, by employing a variety of methods to protect against catastrophe -- one of these methods involves building locks to quickly redirect the flow of water to another channel. Similarly, in the event of an internet service catastrophy, f-lock will block flow into the failed service.

## Arch

F-lock requires a couple of moving parts --sigh.

* Amazon's Route53
* Apex domain access
* 2 or more independent platforms
* Your application
* Desire for availability

### Topology

![img](http://f.cl.ly/items/3t1E031V0E1n3t2U1v2e/arch.png)

## Usage

```bash
$ export AWS_ACCESS=key
$ export AWS_SECRET=secret
$ export AWS_API_V=2012-02-29
$ export CLOUD=primary
$ bin/f-lock ha.com. app
```
