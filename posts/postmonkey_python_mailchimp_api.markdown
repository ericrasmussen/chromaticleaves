---
title: PostMonkey Overview and Updated Docs
date: 2013-07-03
tags: code, python
metadescription: Learn more about mailchimp API integration in python using postmonkey
---

#### Prelude: why MailChimp?

If you're writing a python application and need to integrate with a
service for email marketing, chances are [MailChimp](http://mailchimp.com/)
won't be your first choice. It's nothing against MailChimp; I like them. But
like it or not, they're the WordPress of email marketing software, and us
python folk prefer hot new APIs more than fancy GUIs with tons of features.

Where MailChimp really shines is when you need to put all of that fancy email
design power and campaign analytics into the hands of marketing or other
departments. It's always nice to remove a continual source of IT headaches with
an affordable service that your users actually like. When I came across that
exact use case but needed to automate some tasks, I spent time reading up
on their API.

#### Detour: choosing an API wrapper

At the time I wrote PostMonkey, were a handful of python wrappers for
MailChimp's API. They were all written for different use cases and serve their
purpose, but there were a few red flags for my use case/expectations:

  #. No unit tests
  #. Generally untestable code (hardcoded URLs and urllib references abound)
  #. Little or no documentation
  #. No JSON API support (leading to awkward code with PHP style "arrays")
  #. No pythonic exception handling
  #. Some were django only

[PostMonkey](https://postmonkey.readthedocs.org/en/latest/) was born!

#### PostMonkey Basics

Once you create an instance of PostMonkey with your API key, you can call
methods on it using the exact method names from MailChimp's official [API
v1.3](http://apidocs.mailchimp.com/api/1.3/). PostMonkey uses the JSON API, so
in general the python types will line up with the API types as expected (string
-> string, int -> number, float -> number, dict -> object/associative array,
list -> array, etc).

If there's any interest, at some point I may write up a guide on how to
translate the MailChimp-isms to python-isms. It'd be a lot less work than
trying to re-document their entire API. In the meantime, you can infer a whole
lot from some examples:


```python
# create a PostMonkey instance with a 10 second timeout for each API call
from postmonkey import PostMonkey
pm = PostMonkey('your_api_key', timeout=10)

# get the IDs for your campaign lists
lists = pm.lists()

# print the ID and name of each list
for mylist in lists['data']:
    print mylist['id'], mylist['name']

# subscribe "emailaddress" to list ID 5
pm.listSubscribe(id=5, email_address="emailaddress")

# catch an exception returned by MailChimp (invalid list ID):
from postmonkey import MailChimpException
try:
    pm.listSubscribe(id=42, email_address="emailaddress")
except MailChimpException, e:
    print e.code  # 200
    print e.error # u'Invalid MailChimp List ID: 42'

# get campaign data for all "sent" campaigns:
campaigns = pm.campaigns(filters=[{'status': 'sent'}])

# print the name and count of emails sent for each campaign
for c in campaigns['data']:
    print c['title'], c['emails_sent']
```

#### Documentation Updates

I'd been hosting the PostMonkey docs on my own for a while now, and one day
decided to compare the benefits of that approach to the benefits of using Read
the Docs. You can guess who won:

[http://postmonkey.readthedocs.org/](http://postmonkey.readthedocs.org/)

And, after viewing the docs there, I realized they needed some touching up.
Some of the recent updates include:

* general cleanup to improve readability
* breaking the documentation into separate pages
* understanding how arrays in MailChimp's API translate to json


#### Next steps

MailChimp has a large API, and parts of it are very closely tied with their
server-side PHP. It's entirely possible that my general approach to an API
wrapper has missed edge cases that I wasn't able to test on my personal account
or in the projects I've worked on for clients. If you are having trouble
deciding on which wrapper to use, give PostMonkey a try, and if there is some
dark corner of the MailChimp API that's missing, open an issue and I will
do everything I can to address it.

Also if you have any feature requests or suggestions for PostMonkey,
please [open an issue](https://github.com/ericrasmussen/postmonkey/issues/new)
and get in touch. You can also reach me (erasmas) in #pyramid on freenode.

