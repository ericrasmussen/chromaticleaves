---
title: Integrating MailChimp with Pyramid
date: 2013-07-05
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

Before creating the script, let's add the API key to your Pyramid configuration
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
    env['registry'].settings

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

    # attempt the batch subscribe and handle the error if it fails
    try:
        postmonkey.listBatchSubscribe(batch=new_subscribers)
    except MailChimpException, e:
        print 'failed with MailChimp error: %s' % e.error

    # cleanup
    env['closer']()
```

When you setup your application, the script will be available in your bin/
directory as a standalone script, making it easy to run with cron or a task
scheduler of your choice.

Note also that you don't need to manage the settings in your config file. You
could just as easily write:

```python
from postmonkey import PostMonkey
postmonkey = PostMonkey(my_api_key)
```

But in most cases it's much more convenient to manage the settings along with
your other application settings.


#### PostMonkey in views

Although it's not recommended, there are certain cases where you may want to
make calls to MailChimp inside a view, even if it means blocking the view
response. You should be sure to set a ```postmonkey.timeout``` setting (in
seconds) in your config:

```
postmonkey.apikey = my_api_key
postmonkey.timeout = 2
```

The timeout setting is passed directly to the *Requests* library to stop the
request if the response takes too long (note though that this setting has
nothing to do with how long the response takes to download). It's unlikely that
you'll need this setting, but if you are going to block responses, it's nice
to have it available and easy to configure.

We'll prepare by adding an application-wide *PostMonkey* instance to the
registry so it will be available to views:

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


