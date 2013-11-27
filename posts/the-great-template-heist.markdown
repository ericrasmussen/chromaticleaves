---
title: The Great Template Heist
date: 2013-11-26
tags: code, haskell
metadescription: An odd introduction to using Heist templates in the Haskell Snap web framework
---

Perhaps contrary to the name, learning Heist bears very little in common with
covert, crafty cons. In fact, if you've only ever worked with programmable
template engines or template attribute languages, the journey to Heist
proficiency is one that would make Lewis Carrol proud<sup>[1](#footnote1)</sup>.

#### Types of templating languages

It's important to note, at this juncture, that my experience with server-side
templates has been heavily influenced by popular python libraries like Mako,
Jinja 2, and Chameleon.

The former two fall firmly into the programmable category, meaning you can use
a specialized syntax in the templates to express programming logic along with
your markup:

```
<!-- mako example: displaying a table of active users -->
<table>
% for user in users:
  % if user.active:
    <tr>
      <td>${user.name}</td>
      <td>${user.email}</td>
    </tr>
  % endif
% endfor
</table>
```

Which, if you're both programmer and designer, works pretty well most of the
time. However, many find this approach... distasteful. Almost PHP-ish in its
tangled web of markup and code. Chameleon's answer is a Template Attribute
Language (TAL), where you enforce proper markup by embedding logic in tag
attributes.

```
<!-- chameleon example: displaying a table of active users -->
<table>
  <tal:repeat="user users">
    <tr tal:condition="user.active">
      <td>${user.name}</td>
      <td>${user.email}</td>
    </tr>
  </tal:repeat>
</table>
```

This does address the problem of enforcing correct markup (and your editor
doesn't need to be aware of a special template language), but we've really just
shifted around where the logic lives in the templates; it's still there.

#### Zero control flow

Heist takes an even more extreme view: no control flow or logic in the
templates. This may not be *entirely* accurate (it does have a couple of basic
constructs built into the templating language, such as bind and apply), but
compared to our other examples it's a whole new world of template purity.

But if we can't use our templates to express conditions and repeating sections,
what can we use?

Drum roll please... Haskell!

A different way of viewing Heist is that it's not so much a templating engine
as a library for manipulating markup templates. Our previous user example might
look like this:

```
<!-- heist example: displaying a table of active users -->
<table>
  <activeUsers>
    <tr>
      <td><userName/></td>
      <td><userEmail/></td>
    </tr>
  </activeUsers>
</table>
```

We can now write plain old Haskell code that uses Heist libraries to:

* filter a list of users to find active users only
* map over the list and create splices mapping the user name and email keys to
  their corresponding values
* bind the resulting list of splices to the "activeUsers" node and replace its
  contents with each of the user rows

It's easier to understand all of this when you see the Heist definition of a
template:

```haskell
type Template = [Node]
```

Where a Node is an element in a Document from the Text.XmlHtml library.

Conceptually, then, the Heist libraries provide an API for taking apart a
template node by node and putting it back together again, optionally splicing in
dynamically generated elements or text. Let's see the supporting code for our
example:

```haskell
-- assuming we have a way to pass in the filtered list of Users
activeUsersSplices :: [User] -> Splices (SnapletISplice App)
activeUsersSplices users = "activeUsers" ## (bindUsers users)

bindUsers :: [User] -> SnapletISplice App
bindUsers = I.mapSplices $ I.runChildrenWith . userSplices

userSplices :: Monad n => User -> Splices (I.Splice n)
userSplices (User name email) = do
  "userName"  ## I.textSplice name
  "userEmail" ## I.textSplice email
```


#### Navigating the Heist landscape

Once you embrace this view of Heist libraries with APIs for manipulating
templates, the next task is learning the libraries. At a high level, here are
the starting points:

| Library | Use |
|---------|-----|
| [Heist.Interpreted](http://hackage.haskell.org/package/heist) | a simpler API for splices that are interpreted at runtime |
| [Heist.Compiled](http://hackage.haskell.org/package/heist/docs/Heist-Compiled.html) | a more efficient but slightly more complicated API for compiled splices |
| [Heist.SpliceAPI](http://hackage.haskell.org/package/heist/docs/Heist-SpliceAPI.html) | handy syntactic sugar for working with splices |
| [Snap.Snaplet.Heist](http://hackage.haskell.org/package/snap/docs/Snap-Snaplet-Heist.html) | convenience functions for using Heist in a Snap application |


#### Break out the paint: we've got ourselves a bikeshed

I've been dragged into many a silly argument about templating engines, and
I frequently hear two arguments (to varying degrees) against programmable
template engines:

1. Think of the poor designers! How will they design around funky code?
2. Keep your business logic out of my templates! Separate all the concerns!

OK, maybe they aren't that extreme. But, in my experience, these points get
brought up regularly such arguments. Unfortunately, I don't think these are
tenable positions, because:

1. You can find designers that only hand over static pages, so you handle the
   integration anyway, and you can find designers that are willing to learn and
   work with what you have. Both extremes, and everything in
   between.<sup>[2](#footnote2)</sup>
2. Some degree of logic in the templates can be convenient, and can even better
   communicate your intent: by reading the template, you know what sections
   should repeat, which should be rendered conditionally, etc., without having
   to read code.

The bottom line is we're discussing matters of taste and preference, so there
can't be a single right answer. When you let go of the aesthetics, it's most
important that you choose what will work best for everyone involved. Don't get
pulled into drawn out arguments about how one or another approach doesn't hold
up; all of the high level templating approaches work just fine, even in very
large applications with large teams.


#### The Payoff

So if I'm not recommending Heist as a designer friendly templating system
free of deadly magic and business logic, what's the real payoff?

In my opinion it's much more subtle: you can write more Haskell. You don't have
to find a way to express what you want in a subset of the language or a DSL.
You can take full advantage of the language, its type system, your text editor,
etc. And after all, one of the greatest advantages of using Haskell is being
able to reason about the code, follow the types, and interact it your code
in GHCi.

And remember that in doing so, you can always write the higher level facilities
you need for your app. Identify points in your application where you're
writing boilerplate, and DRY it up the same as you would in any Haskell module.

#### Hidden Perils

There are a handful of caveats you should be wary of when learning Heist. Note
that so far I have only spent time with Heist's interpreted splices, so these
may not all apply to compiled splices.

1. Templates are called by text referencing the template name, so you will get
   runtime errors if you rename templates or reference non-existing templates
   (since many of us use Haskell for compile time safety, this is troubling,
   but this is intentional: Heist treats templates as data rather than code).
2. You can't express your intentions in a template. If I can see a ``for`` loop
   in a template, I know a section will repeat. In Heist, you can only infer
   this by tag names and comments, unless you take the time to read all of the
   code. I feel like it does lose something by requiring you to know both code
   and templates to fully understand the interactions, but this is true to
   varying degrees in all template systems regardless.
3. Compiled splices and interpreted splices share some of the same API, but they
   are not interchangeable. You need to decide upfront which is going to make
   the most sense for your application, or plan for some refactoring later if
   you start with interpreted and may need to move to compiled for a performance
   boost later on.

Compared to the relative dangers of any template system, none of these are
compelling reasons not to use Heist, but it's important to keep them in mind
as you're learning it.

#### Show me the code!

I have a bad habit of making my learning process public. In this case, I worked
through some flow control basics in Heist (using interpreted splices), and
wanted to share. You can view the
[snap-heist-examples repo](https://github.com/ericrasmussen/snap-heist-examples)
to see
[standalone Snap handlers](https://github.com/ericrasmussen/snap-heist-examples/tree/master/src/handlers)
that demonstrate different ways to repeat or conditionally include text and
templates.

Contributions or issues/ideas are very welcome. As I work through other examples
I will try to distill them and add them to this repo, with the intent of
building up a nice set of Heist examples in the context of a working Snap
application.

<hr />

<sub><a id="footnote1">1.</a> I've already reached my quota for the phrase
"down the rabbit hole". I expect I'll continue to use more and more obscure
variations on that theme, so steel yourselves.</sub>

<sub><a id="footnote2">2.</a> If any research has been done on what most
designers prefer, please send details to eric @ chromatic leaves dot com.</sub>
