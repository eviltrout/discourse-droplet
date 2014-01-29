discourse-droplet
=================

A ruby script for installing Discourse on Digital Ocean using a simple wizard.
Behind the scenes it makes heavy use of [discourse_docker](https://github.com/discourse/discourse_docker).

Usage
=====

```bash
$ bundle install
$ ruby deploy.rb
```

Then you can go through the wizard like so:

```bash
Your Digital Ocean Client id:
YOUR_CLIENT_ID

Your Digital Ocean API Key:
YOUR_API_KEY

Your developer email address:
your.email@provider.com

Host of Discourse forum (example: eviltrout.com)
awesomeforum.com

Confirm Your Settings
=====================
Host: awesomeforum.com
Email: asdf@.asdf.com
SSH Key: Evil Trout

Type 'Y' to continue
Y


... a bunch of crazy output ...



Discourse is ready to use:
http://awesomeforum.com
http://192.168.0.1    (the IP of your Droplet)

```

And you should be able to access your new forum in your browser. So easy!

Next Steps, Upgrading, etc.
===========================

For upgrading instructions, check out the [discourse_docker](https://github.com/discourse/discourse_docker).

For more information about configuring Discourse, check out [discourse](http://github.com/discourse/discourse).

License
=======

MIT



