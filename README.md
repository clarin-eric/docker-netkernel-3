Basic docker setup for NetKernel 3
==================================

This Docker setup provides a [NetKernel](http://www.1060research.com) 3 application server.

* downloads the last release by 1060 Research
* patches the kernel
* fetches the latest module updates
* applies our patches to some modules
* adds some 3rd party modules
  * mod-e4x by Chris Wensel
  * db-metadata by Steve Harris
  * mod-stink by Tom Hicks
* adds our own SLOOT (= TOOLS) module
