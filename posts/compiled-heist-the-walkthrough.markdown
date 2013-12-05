---
title: Compiled Heist: The Walkthrough
date: 2013-12-04
tags: code, haskell
metadescription: An odd introduction to using compiled Heist templates in the Haskell Snap web framework
---

This tutorial post is going to jump right in to learning about and using the
Heist.Compiled module inside a Snap application. If you've never used Heist
before, you may want to start with the much gentler introduction from my
previous post: [The Great Template Heist](/posts/the-great-template-heist.html).


#### There can only be one (not really)

Heist now comes in two flavors: interpreted and compiled. The former has been
around longer, is more flexible, and has a very accessible API. It is plenty
fast for many use cases, but inefficient because it requires traversing
templates node by node each time they're rendered.

Compiled Heist takes a different approach: it compiles as much of the templates
down to ByteStrings as possible, letting you fill in runtime values only where
you need them. The result is a staggering performance gain, with some compiled
templates rendering at more than 3000x the speed of their interpreted
equivalents.<sup>[1](#footnote1)</sup>

The price you pay for these huge gains in performance is having to specify and
load all of your compiled splices, once, at the top level of your application.

Take a moment to let that sink in: all of your top level splices need to be
pre-defined and available at the time your application loads. Unlike interpreted
Heist, you can't bind local splices to a template at render time. When you
render a compiled template in a Snap Handler, the only splices it can use are
those you defined in your HeistConfig.

#### Runtime splices and node reuse

If you're only familiar with interpreted splices, you might be wondering how this
inversion of control affects us. Specifically, two questions come to mind:

1. If we need to pre-define our splices, how can we render dynamic values?
2. If we can only bind a node to a single compiled splice, how can we reuse nodes?

The first problem can be solved with the notion of a RuntimeSplice, which you
can think of as a computation that will be evaluated at runtime each time its
needed, letting you perform the IO and logic you need for accessing databases,
reading from files, etc.

We can reuse nodes by declaring any compiled splices we need within the top
level splice. You can think of it as nesting splices, or inner splices, or
binders full of splices, or... nevermind. Let's just work through an example.


#### Listing things

Here's a sample template where the `<allTutorials>` node contains nodes
representing one table row for a single tutorial. We'd like to be able to repeat
those nodes once for each tutorial in a list of tutorials:

```html
<table>
  <thead>
    <tr>
      <th>Title</th>
      <th>Author</th>
    </tr>
  </thead>
  <tbody>

  <allTutorials>

    <tr>
      <td>
        <a href="${tutorialURL}"><tutorialTitle/></a>
      </td>
      <td>
        <tutorialAuthor/>
      </td>
    </tr>

  </allTutorials>

  </tbody>
</table>
```

We'll get started by defining a simple tutorial type:

```haskell
data Tutorial = Tutorial {
    title  :: Text
  , url    :: Text
  , author :: Text
  }
```

Now, remember we mentioned being able to defer computations until runtime? To
keep things simple we're going to return a constant list of Tutorials as the
result of a RuntimeSplice computation, but in a real world app you could query a
database or obtain the list from another source:

```haskell
tutorialsRuntime :: Monad n => RuntimeSplice n [Tutorial]
tutorialsRuntime = return [ Tutorial "title1" "url1" "author1"
                          , Tutorial "title2" "url2" "author2"
                          ]
```

Here's where things get interesting: there is virtually no API for working
directly with RuntimeSplices, so we can't easily inspect the underlying runtime
value and bind the result to a node name. Instead, we're going to create
Splices containing a function that can do this for us. Note that in the examples
below, Heist.Compiled is imported as `C`.

```haskell
splicesFromTutorial :: Monad n => Splices (RuntimeSplice n Tutorial -> C.Splice n)
splicesFromTutorial = mapS (C.pureSplice . C.textSplice) $ do
  "tutorialTitle"  ## title
  "tutorialURL"    ## url
  "tutorialAuthor" ## author
```

Remember that title, url, and author are functions defined in our Tutorial
type. So our do block contains a value of type `Splices (Tutorial -> Text)`.
We then map over those splices to create pure splices from each.

If this all sounds a little heavy, don't panic! It takes some time working with
functions in the Heist.Compiled module to build fluency. No amount of
explanation is going to make the reason for this immediately clear; it's simply
one way we can leverage the higher level compiled splice functions we have
available to us.

But you *should* make an effort to follow the types as we go, even if only in
the abstract. Here are the type signatures for the Heist functions we used
above:

```haskell
textSplice :: (a -> Text) -> a -> Builder

pureSplice :: Monad n => (a -> Builder) -> RuntimeSplice n a -> Splice n

mapS :: (a -> b) -> Splices a -> Splices b
```

In our case, the splices first contain a function of `Tutorial -> Text`, which
is passed to textSplice, giving us a function of `Text -> Builder`, which is
what pureSplice expects as its first argument.

The end result is a series of splices where node names map to functions of
`RuntimeSplice n Tutorial -> C.Splice n`. Compiled Heist gives us a few options
for working with splices containing functions of this type. Here's how we can
map over a list of runtime tutorials and create a single compiled splice
containing all of the rendered tutorial splices:

```haskell
renderTutorials :: Monad n => RuntimeSplice n [Tutorial] -> C.Splice n
renderTutorials = C.manyWithSplices C.runChildren splicesFromTutorial
```

For posterity, here are the type signatures for the supporting Heist.Compiled
functions used above:

```haskell
runChildren :: Monad n => Splice n

manyWithSplices :: Monad n
                => Splice n
                -> Splices (RuntimeSplice n a -> Splice n)
                -> RuntimeSplice n [a]
                -> Splice n
```

It's a lot to take in, but follow through step by step to see that everything
lines up.

Now we have a way to process a runtime computation returning a list of
tutorials, create individual tutorial splices for each tutorial, and return it
as a single compiled splice. This is a very important point that gets to the
core of compiled Heist: we can reuse splices (and thus nodes in a template)
however we want, as long as we compile them down to a single splice this way.

We can then create top level splices that will map the outer `<allTutorials>`
node to this compiled splice:

```haskell
allTutorialSplices :: Monad n => Splices (C.Splice n)
allTutorialSplices =
  "allTutorials" ## (renderTutorials tutorialsRuntime)
```

Once we have the fully compiled splices, we can add them to our HeistConfig so
it will be available to our template when rendered:

```haskell
app :: SnapletInit App App
app = makeSnaplet "app" "A snap demo application." Nothing $ do
    h <- nestSnaplet "" heist $ heistInit "templates"
    -- add the compiled splices to our HeistConfig
    addConfig h $ mempty { hcCompiledSplices = allTutorialSplices }
    -- the rest of your SnapletInit
```

At this point all that remains is rendering the template in a Snap handler:

```haskell
tutorialHandler :: Handler App App ()
tutorialHandler = cRender "tutorials"
```

Notice again that unlike interpreted splices, we don't (and can't!) provide
local splices specific to this template. When our handler renders the template,
those splices will be automatically found in our HeistConfig.

The above walkthrough will hopefully give you enough insight to get started,
but check out the
[snap-heist-examples](https://github.com/ericrasmussen/snap-heist-examples/)
repo for a complete working version with all of the required imports, other
examples, and a cabal file listing the library versions used here.

#### Choosing between interpreted and compiled

It'd be nice if I could tell you to start with interpreted splices on your next
project and only move to compiled splices when you need extra speed. I'm all for
keeping things simple and avoiding premature optimization, and interpreted
splices are plenty fast for many use cases.<sup>[2](#footnote2)</sup>

What gives me pause is that compiled splices give you a dramatic performance
improvement without much extra effort, provided you plan for them in the
beginning. This extra effort isn't a bad thing either: it forces you to really
think through how you obtain data and expose it to templates at the application
level, whereas interpreted splices make it a little easier to play fast and
loose with splices that can change locally depending on the template and
particular view.

Compiled splices only introduce one major caveat: they won't stop you from
declaring splices with the same node name, and it will happily let you overwrite
duplicate values.<sup>[3](#footnote3)</sup> Let's say you make two different
compiled splices for a "userName" node used in separate templates, and put both
in your Heist config.  One of them will be silently overwritten, and the value
it returns could be used in both templates.

I can think of a lot of ways this could be very dangerous (say, accidentally
displaying every user's account on an individual user profile page because you
used the same node name for both). I do not think this is a likely accident, but
you should definitely take precautions to ensure your Heist config doesn't
contain any surprises. Hopefully at some point in the future we'll get a way to
specify compiled splices for particular templates so we can explicitly control
this behavior.

#### More examples and tutorials

I updated my [snap-heist-examples
repo](https://github.com/ericrasmussen/snap-heist-examples) with comparable
compiled versions of the original interpreted examples. It's not a bad place to
start if you want to see Heist used in the context of a Snap application, and it
should be relatively straightforward to clone the repo and build the app locally
if you need a playground for learning Snap and Heist.

Here are some additional resources for learning more:<sup>[4](#footnote4)</sup>

* [Heist Template Tutorial](http://snapframework.com/docs/tutorials/heist)
* [Compiled Splices Tutorial](http://snapframework.com/docs/tutorials/compiled-splices)
* [Attribute Splices Tutorial](http://snapframework.com/docs/tutorials/attribute-splices)
* [Compiled Heist insight, with no Snap in sight](https://www.fpcomplete.com/school/to-infinity-and-beyond/older-but-still-interesting/compiled-heist-insight-with-no-snap-in-sight)
* [The Great Template Heist](/posts/the-great-template-heist.html)


<hr />

<sub><a id="footnote1">1.</a> Details available in the [original
announcement](http://snapframework.com/blog/2012/12/9/heist-0.10-released).</sub>

<sub><a id="footnote2">2.</a> We often talk about speed in relative terms as
if it's meaningful, but it's not. Unless you benchmark and know what your
expected load is, you really can't rule out interpreted splices on the grounds
that they "aren't fast enough" for you, even though it's tempting.</sub>

<sub><a id="footnote3">3.</a>The [SpliceAPI module](http://hackage.haskell.org/package/heist-0.13.0.2/docs/Heist-SpliceAPI.html)
exports a "#!" combinator that is similar to "##" but throws an error if there is a duplicate.
</sub>

<sub><a id="footnote4">4.</a> If you write a Heist tutorial and would like to
add it to the list, [open an issue](https://github.com/ericrasmussen/chromaticleaves/issues)
or send a pull request.</sub>
