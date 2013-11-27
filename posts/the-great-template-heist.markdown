---
title: The Great Template Heist
date: 2013-11-27
tags: code, haskell
metadescription: An odd introduction to using Heist templates in the Haskell Snap web framework
---

Heist is a powerful templating engine written in Haskell, and commonly used in
Snap web applications. But if you've only ever worked with programmable template
engines or template attribute languages, the journey to Heist proficiency is one
that would make Lewis Carroll proud<sup>[1](#footnote1)</sup>.

But first: what's in a template?

#### A template's journey: there and back again

My experience with server-side templates has been heavily influenced by popular
python libraries like Mako, Jinja 2, and Chameleon.

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
time. However, some find this approach... distasteful. An alternative is
a TAL (Template Attribute Language) like Chameleon, where you embed logic in tag
attributes so you can still enforce proper markup:

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

This gives us cleaner markup, but the logic is still embedded in the template.

#### Zero control flow

Heist takes an even more extreme view: no control flow or logic in the
templates. This may not be *entirely* accurate (it does have a couple of basic
constructs built into the templating language, such as bind and apply), but
compared to our other examples it's a whole new world of template purity.

Our previous user example might look like this:

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

We can now write plain old Haskell code to:

* filter the user list for active users
* map over the list to create user name and email splices
* run the user splices against the contents of `<activeUsers>`
* bind the result to the `<activeUsers>` node

One helpful way of viewing interpreted Heist is that it's not so much a
templating engine as a library for manipulating templates. An API for taking a
template apart node by node and putting it back together again, optionally
splicing in dynamically generated elements or text. In fact, a Heist template is
literally a list of nodes:

```haskell
-- a Node is an element in a Document from the Text.XmlHtml library
type Template = [Node]
```

Here's the supporting code to bring it all together:

```haskell
-- binds a list of splices to <activeUsers> (assumes we pass in active users)
activeUsersSplices :: [User] -> Splices (SnapletISplice App)
activeUsersSplices users = "activeUsers" ## (bindUsers users)

-- maps over a list of users to create splices for each
bindUsers :: [User] -> SnapletISplice App
bindUsers = I.mapSplices $ I.runChildrenWith . userSplices

-- creates the <userName/> and <userEmail/> splices for an individual user
userSplices :: Monad n => User -> Splices (I.Splice n)
userSplices (User name email) = do
  "userName"  ## I.textSplice name
  "userEmail" ## I.textSplice email
```


#### Navigating the Heist landscape

Once you embrace this view of Heist as functions for manipulating templates, the
next task is learning the libraries. Here's the high level breakdown:

| Library | Use |
|---------|-----|
| [Heist.Interpreted](http://hackage.haskell.org/package/heist/docs/Heist-Interpreted.html) | API for splices interpreted at runtime |
| [Heist.Compiled](http://hackage.haskell.org/package/heist/docs/Heist-Compiled.html) | a slightly more complicated API for (more efficient) compiled splices |
| [Heist.SpliceAPI](http://hackage.haskell.org/package/heist/docs/Heist-SpliceAPI.html) | handy syntactic sugar for working with splices |
| [Snap.Snaplet.Heist](http://hackage.haskell.org/package/snap/docs/Snap-Snaplet-Heist.html) | convenience functions for accessing Heist state in a Snap application |


#### Intermission: new paint for the bikeshed

Choosing a template engine is kind of like choosing a text editor: everyone's
sure their approach is best, and sooner or later you'll be dragged into
silly arguments.

With programmable template engines, people are often quick to mention how we
need a clean separation of concerns to keep business logic from ruining our
pristine templates, and won't you think of all the poor designers out there who
just want to work with valid markup.

They sometimes neglect to mention that for some teams, expressing logic in
templates is a benefit (it can clarify intent, and may be preferred when
programmers are solely responsible for integrating markup), or that designer
preferences vary. I have worked with designers that only hand off static assets
and require the developers to handle 100% of the integration, and I've worked
with designers that take the time to learn enough of your chosen framework and
templating system to work with it.<sup>[2](#footnote2)</sup>

The bottom line is we're discussing matters of taste and preference, so there is
no right answer. It depends on the context and how well it's going to work for
everyone involved on the project.


#### The Heist payoff

If your preference is designer friendly templating systems free of dangerous
magic and unclean business logic, Heist is the go-to Haskell template library
for you. But it's not my own typical use case, and it's not the grounds on which
I'd recommend choosing it.

The payoff for me turned out to be much more subtle: you can write more
Haskell. You don't have to find a way to express what you want in a specialized
template language. You can take full advantage of the language, its type
system, GHCi, your tricked out text editor, etc.

This approach can require more code if you're used to the convenience of
programmable templates, but it also forces you to be more conscious about how
you're manipulating data and exposing it to templates. And at the end of the
day, you're writing Haskell: if you find yourself writing boilerplate, there's
probably an abstraction you can use to DRY it up.


#### Show me the code!

I have a bad habit of making my learning process public. In this case, I worked
through some control flow basics in Heist (using interpreted splices), and
wanted to share. You can view the
[snap-heist-examples repo](https://github.com/ericrasmussen/snap-heist-examples)
to see
[standalone Snap handlers](https://github.com/ericrasmussen/snap-heist-examples/tree/master/src/handlers)
that demonstrate different ways to repeat or conditionally include text and
templates.

Contributions or issues/ideas are very welcome.

<hr />

<sub><a id="footnote1">1.</a> In lieu of saying "down the rabbit hole" again, a
phrase I repeat far too often. I expect I'll continue to use more and more
obscure variations on that theme. Steel yourselves.</sub>

<sub><a id="footnote2">2.</a> If you know of any actual studies on designer
preferences, please send details to eric @ chromatic leaves dot com.</sub>
