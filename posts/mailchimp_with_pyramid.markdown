---
title: Integrating MailChimp with Pyramid via PostMonkey
date: 2013-06-30
tags: code, python, pyramid
metadescription: Learn how to integrate MailChimp into your Pyramid Applications using the python PostMonkey library
---

#### Prelude: why MailChimp?

If you're writing a Pyramid application and you want to integrate with a
service for email marketing, chances are [MailChimp](http://mailchimp.com/)
won't be your first choice. It's nothing against MailChimp; I like them. But
like it or not, they're the WordPress of email marketing software, and us
python folk prefer hot new APIs more than fancy GUIs with tons of features.

Where MailChimp really shines is when you need to put all of that fancy email
design power and campaign analytics into the hands of marketing or other
departments. It's always nice to remove a continual source of IT headaches with
an affordable service that your users actually like, so when I came across that
exact use case, I spent some time reading up on their API.


#### Detour: choosing an API wrapper

At the time I wrote *PostMonkey*, were a handful of python wrappers for
MailChimp's API, but while they all serve their purposes, there were a few red
flags for my use case:

  #. No unit tests
  #. Generally untestable code (hardcoded URLs and urllib references abound)
  #. No JSON API support (leading to awkward code with PHP style "arrays")
  #. No pythonic exception handling
  #. Some were django only

[PostMonkey](https://postmonkey.readthedocs.org/en/latest/) was born!


#### PostMonkey in console_scripts

One of the first things I learned about MailChimp's API is it's not well suited
to real time usage. They have the bandwidth, but even some of the basic
subscribe/unsubscribe API calls can be slow. The recommended approach is to
batch requests. Here's a partial example of a console script in a pyramid
application:

```
# in your ini file
postmonkey.apikey = my_api_key
```


```python

# in your script
from pyramid.paster import bootstrap
from postmonkey import postmonkey_from_settings

def my_script_entry():
    env = bootstrap('/path/to/my/development.ini')
    env['registry'].settings
    postmonkey = postmonkey_from_settings(**settings)

    for new_subscriber in some_list:
        postmonkey.listSubscribe(id=42, email_address=new_subscriber)

    env['closer']()

```

There are additional steps to make the above into a proper console script, and
the Pyramid docs have a whole chapter on it:
[Command-Line Pyramid](
http://docs.pylonsproject.org/projects/pyramid/en/latest/narr/commandline.html).

Note also that you don't need to manage the settings in your config file. If you
have a non-Pyramid script you could just as easily write:

```python
from postmonkey import PostMonkey
postmonkey = PostMonkey(my_api_key)
```

#### PostMonkey in views


If you do want realtime support with an application-wide *PostMonkey* instance,
your best bet is:

```
# in your ini file
postmonkey.apikey = my_api_key
postmonkey.timeout = 300
```

```python
# in your app startup
from postmonkey import postmonkey_from_settings

def main(config, **settings):
    postmonkey = postmonkey_from_settings(**settings)
    config.registry.postmonkey = postmonkey

# in a view
@view_config(route_name='myview')
def myview(request):
    postmonkey = request.registry.postmonkey
    try:
        postmonkey.listSubscribe(id=42, email_address="emailaddress")
        return Response('OK!')
    except PostRequestError, e:
        # e is the underlying exception from the Requests library
        # (likely a timeout based on our postmonkey.timeout seconds)
        return Response('Not so good!')
```

#### Next steps

*PostMonkey* is in no way dependent on Pyramid, but if there is any interest in
the Pyramid community, I can package up a *pyramid_mailchimp* package that would
reduce the realtime example above to:

```python
config.include('pyramid_mailchimp')
```

If you have any feature requests or suggestions for *PostMonkey*
please [open an issue](https://github.com/ericrasmussen/postmonkey/issues/new)
and get in touch. You can also reach me (erasmas) in #pyramid on freenode.
