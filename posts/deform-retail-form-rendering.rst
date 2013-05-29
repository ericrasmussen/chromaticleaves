---
title: Deform Retail Form Rendering
date: 2013-05-28
tags: code, python, pyramid
metadescription: Learn about deform retail form rendering in python web applications (examples in pyramid)
---

If you write web applications, chances are you've come across the dubious
entities known as "forms". The delicate interplay between html, css, javascript,
server side code, databases, and expectations from your users cannot be
understated.  So let me say it plainly: forms are hard.

There's simply no way to write an all encompassing form library for every use
case. Every form library is going to make tough choices and tradeoffs that
affect its usability to you as a developer, its extensibility, and its UI for
your users. Often times it can be difficult to learn a form library in its
entirety because of this complexity, and that's likely one reason many
programmers end up writing their own instead.

In the python world we now have over 100 form validation and related libraries
on pypi*. The power of choice can be debilitating, so I'll make it simple. You
should learn ``deform``.

When you drill down past all the complexities, the core abstraction behind forms
is mapping user input to code. One way to do that is writing and validating
schemas. ``deform`` achieves this by building on the excellent ``colander``
library.  And while no form library will cover all use cases, ``deform`` has
hooks in all the right places to make it extremely flexible and extensible. If
you haven't tried it before, start here:

#. `Deform Documentation <http://deform.readthedocs.org/en/latest/>`_
#. `Deform Demo Site <http://deformdemo.repoze.org/>`_

Of course, there's just one catch: ``deform``'s tradeoff was developer
flexibility over highly customizable front-end forms. Typically you would build
up a ``deform.Form`` object, render it to html with a pre-defined template, and
pass it off wholesale to your page template. This makes front-end customizations
a lot of work because you'd need to create separate form templates for each (in
addition to your page templates) and override ``deform`` assets to use the
correct templates.

For that reason I'd only been using ``deform`` for use cases where pre-generated
forms were a reasonable tradeoff. The good news is the library has a new feature
called retail form rendering (named for customer facing/retail website forms)
that lets you pass the ``Form`` object to your page template instead. This may
sound like a small addition to the library, but the implications are huge. You
can now access and manipulate ``Form`` and field objects directly in your page
templates, giving you full control over how to style them.

This features deserves a lot more attention than it's getting, so I created a
demo site in pyramid to highlight some of its capabilities:

* `Deform Retail Form Demos <http://deformretail.chromaticleaves.com/>`_

Please feel free to open an issue on `github
<https://github.com/ericrasmussen/deform_retail_demo/issues>`_ if you have any
forms you'd like to see, or you can even issue a pull request showing off new
forms.

Until you actually dig into ``deform``'s API, it's a little hard to appreciate
just how expressive it is. Like many libraries that tackle hard problems, it
requires a lot of effort. It may even look like it'd be more effort to learn it
than roll your own. But likely it isn't, and
you'll be doing yourself a service investing that time in ``deform``.


:sub:`*In the pypi listing, deform is described rather
inconspicuously as "Another form generation library"`

