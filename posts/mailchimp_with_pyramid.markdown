---
title: Integrating MailChimp with Pyramid
date: 2013-07-11
tags: code, python, pyramid
metadescription: Learn how to integrate MailChimp into your Pyramid Applications using the python PostMonkey library
---

#### Overview

MailChimp is a full-featured email marketing service, complete with hosted
forms for your users to subscribe or unsubscribe, nice import/export features
for campaign statistics, and a whole lot more. But if you've chosen to build
a website in Pyramid, chances are you'll want the flexibility to:

* design your own subscribe/unsubscribe forms
* keep customer preferences/custom attributes in sync with MailChimp
* automatically gather campaign statistics for use in other reports

You can write Pyramid views to do any of these things in realtime, but
MailChimp's API is best suited to periodic batch updates, and in general it's
not a good idea to tie up your views with outgoing calls. All of the examples
below use the *PostMonkey* library, and you can read more about it
[here](http://chromaticleaves.com/posts/postmonkey_python_mailchimp_api.html).

To add *PostMonkey* to your Pyramid app, first include it in your setup.py
*install_requires*:

```python
setup(name='my app',
      install_requires=[
          'pyramid',
          'postmonkey',
      ]
     )
```

And run ```python setup.py develop``` (using the python in your virtualenv,
ideally) to install it.


#### PostMonkey in console_scripts

This section assumes you're familiar with creating console scripts using
*pyramid.paster*. If not, the Pyramid docs have a whole chapter on it:
[Command-Line Pyramid](
http://docs.pylonsproject.org/projects/pyramid/en/latest/narr/commandline.html).

Before creating the script, let's add your API key to your Pyramid configuration
file, typically development.ini or production.ini. We'll want to prefix it
with "postmonkey." so *PostMonkey* will recognize it:

```
postmonkey.apikey = my_api_key
```

Now let's look at how you can load *PostMonkey* from the ini file in a Pyramid
console script. This example shows how to batch subscribe new subscribers:

```python

from pyramid.paster import bootstrap
from postmonkey import postmonkey_from_settings
from postmonkey import MailChimpException

def my_script():
    # load a Pyramid environment from your configuration file
    env = bootstrap('/path/to/my/development.ini')

    # access the settings from the registry
    settings = env['registry'].settings

    # create a *PostMonkey* instance from your app settings
    postmonkey = postmonkey_from_settings(**settings)

    # we'll put all the new subscribers in this list
    new_subscribers = []

    # imaginary method to get user objects with the attributes we need
    for subscriber in get_new_subscribers():
        # each subscriber in the batch should be a dict with an 'EMAIL' key,
        # along with any other MailChimp merge_vars like FNAME and LNAME
        attributes = {'FNAME': subscriber.first_name,
                      'LNAME': subscriber.last_name,
                      'EMAIL': subscriber.email_address}

        new_susbcribers.append(attributes)

    # attempt the batch subscribe and handle an exception
    try:
        postmonkey.listBatchSubscribe(batch=new_subscribers)
    except MailChimpException, e:
        print 'failed with MailChimp error: %s' % e.error

    # cleanup
    env['closer']()
```

If you've followed along with the introductory Pyramid tutorials or general
python best practices, you'll install your application in a virtualenv. After
creating your console script and running ```myvirtualenv/bin/python setup.py
develop``` on your application's *setup.py*, your new script will be available
as a standalone script in *myvirtualenv/bin/*. This makes it easy to run with
cron or your favorite task scheduler.

Note also that you don't need to manage the settings in your Pyramid config
file. You could just as easily write:

```python
from postmonkey import PostMonkey
postmonkey = PostMonkey(my_api_key)
```

But in most cases it's much more convenient to manage the settings along with
your other application settings. This is especially helpful when you take
advantage of other available options, including the request timeout setting
we'll see next.


#### PostMonkey in views

Although it's not recommended, there are certain cases where you may want to
make calls to MailChimp inside a view, even if it means blocking the view
response. In these cases, you should be sure to set a ```postmonkey.timeout```
setting (in seconds) in your config:

```
postmonkey.apikey = my_api_key
postmonkey.timeout = 2
```

The timeout setting is passed directly to the *Requests* library to stop the
request if the server takes too long to respond. Note, however, that this only
covers the initial response from MailChimp; once they begin sending a response
it won't time out, even if they're sending a lot of data that takes
time to download.

We'll setup this example by first adding an application-wide *PostMonkey*
instance to the registry so it will be available to views:

```python
# in your app startup
from postmonkey import postmonkey_from_settings

def main(config, **settings):
    postmonkey = postmonkey_from_settings(**settings)
    config.registry.postmonkey = postmonkey
```

You could also create the instance inside views only when you need it (the
settings are always available in ```request.registry.settings```).

Here's an example where we grab some basic campaign statistics:

```python
from postmonkey import PostRequestError

@view_config(route_name='myview', renderer='mytemplate')
def myview(request):
    postmonkey = request.registry.postmonkey

    try:
        # will return a dict (see MailChimp's API docs for details)
        stats = postmonkey.campaignAnalytics(cid=my_campaign_id)
        return {'visits': stats['visits'], 'pages': stats['pages']}

    except PostRequestError, e:
        # e is the underlying exception from the Requests library
        # in our case it is likely a timeout
        return Response('Not so good!')
```

#### Additional resources

If you have any feature requests or suggestions for *PostMonkey*
please [open an issue](https://github.com/ericrasmussen/postmonkey/issues/new)
and get in touch. You can also reach me (erasmas) in #pyramid on freenode.

References:

* [PostMonkey docs](http://postmonkey.readthedocs.org/)
* [MailChimp API docs](http://apidocs.mailchimp.com/api/1.3/)
* [Pyramid docs](http://docs.pylonsproject.org/projects/pyramid/)

#### Notes

This article was written for PostMonkey 1.0b and Pyramid 1.4. Please email
eric at chromatic leaves dot com if you're using newer versions and run into
any issues.

