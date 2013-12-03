---
title: Compiled Heist
date: 2013-12-03
tags: code, haskell
metadescription: An odd introduction to using compiled Heist templates in the Haskell Snap web framework
---

This tutorial post is going to jump right in to learning about and using the
Heist.Compiled module inside a Snap application. If you've never used Heist
before, you may want to start with the much gentler introduction from my
previous post: [The Great Template Heist](/posts/the-great-template-heist.html).


#### I feel the need for speed

Heist now comes in two flavors: interpreted and compiled. The former has been
around longer, is more flexible, and has a very accessible API. It is plenty
fast for many use cases, but inefficient because it requires traversing
templates node by node each time they're rendered.

Compiled Heist takes a different view: it compiles as much of the templates down
to ByteStrings as possible, letting you fill in runtime values only where you
need them.

The result was a staggering performance gain, with some compiled templates
rendering at more than 3000x the speed of their interpreted
equivalents.<sup>[1](#footnote1)</sup>

The price you pay for these huge gains in performance is having to specify and
load your splices, once, at the top level of your application.

Take a moment to let that sink in: all of your top level splices need to be
pre-defined and available at the time your application loads. Unlike interpreted
Heist, you can't bind local splices to a template at render time. You can only
render the template in a Handler, and it will implicitly use any splices already
defined in your HeistConfig.

#### Runtime splices and node reuse

If you're only familiar interpreted splices, you might be wondering how this
inversion of control affects us. Specifically, two questions come to mind:

1. If we need to pre-define our splices, how can we fill in values determined
   only at runtime?
2. If we can only bind a node name to a single compiled splice at the top level,
   how can we reuse nodes?

The first problem can be solved with the notion of a RuntimeSplice, which you
can think of as a computation that will be evaluated at runtime each time its
needed, letting you perform the IO and logic you need for accessing databases,
reading from files, etc.

The second question is answered by rendering a compiled splice within the top
level splice. You can think of it as nesting splices, or inner splices, or
binders full of splices, or...

Let's just work through an example.


#### Listing things

Let's look at an example, rendering a list of tutorials in a table. Here's the
relevant part of our template:

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

In this case we know we'll need to reuse the tutorialURL, tutorialTitle, and
tutorialAuthor nodes once for each tutorial we have. But we only have one top
level splice that we'll need to bind in our HeistConfig: allTutorials.

We'll get started by defining a simple tutorial type:

```haskell
data Tutorial = Tutorial {
    title  :: T.Text
  , url    :: T.Text
  , author :: T.Text
  }
```

Now, remember we mentioned being able to defer computations until runtime? To
keep things simple we're going to return a constant list of Tutorials as a
RuntimeSplice computation, but in a real world app you could query a database
or some other source here:

```haskell
tutorialsRuntime :: Monad n => RuntimeSplice n [Tutorial]
tutorialsRuntime = return [ Tutorial "title1" "url1" "author1"
                          , Tutorial "title2" "url2" "author2"
                          ]
```

Here's where things get interesting: there is virtually no API for working
directly with RuntimeSplices, so we can't easily inspect the underlying runtime
value and bind the result to a node name. Instead, we're going to create
Splices containing a function that can do this for us (C is the Heist.Compiled
module in the following examples):

```haskell
splicesFromTutorial :: Monad n => Splices (RuntimeSplice n Tutorial -> C.Splice n)
splicesFromTutorial = mapS (C.pureSplice . C.textSplice) $ do
  "tutorialTitle"  ## title
  "tutorialURL"    ## url
  "tutorialAuthor" ## author
```

Remember that `title`, `url`, and `author` are functions defined in our Tutorial
type. So our `do` block contains a value of type Splices (Tutorial -> T.Text).
We then map over those splices to create pure splices from each. We can gain
confidence in this approach by spending time working with the available higher
level functions in the Heist.Compiled module, and no amount of explanation is
going to make this approach immediately clear.

However, here are the type signatures (from Heist 13.02) so you can see how
all the types line up:

```haskell
textSplice :: (a -> Text) -> a -> Builder

pureSplice :: Monad n => (a -> Builder) -> RuntimeSplice n a -> Splice n

mapS :: (a -> b) -> Splices a -> Splices b
```

In our case, the splices first contain a function of Tutorial -> Text, which is
passed to textSplice, giving us a function of Text -> Builder, which is what
pureSplice expects as its first argument. The end result is a series of splices
containing functions of RuntimeSplice n Tutorial -> C.Splice n.

A common pattern in Heist is to take splices containing a function of this type,
then apply it to C.manyWithSplices C.runChildren. The result is a function
that will be able to take our original runtime list of tutorials and produce
a compiled splice:

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

To summarize what we've done so far: we now have a way to take a runtime
list of tutorials and create splices from each (that correspond to the nodes in
our template).

Next, we'll need to bind this list of splices to the outer node in our template,
"allTutorials". We can do that by passing the runtime to our renderTutorials
function, and creating splices from the result:

```haskell
allTutorialSplices :: Monad n => Splices (C.Splice n)
allTutorialSplices =
  "allTutorials" ## (renderTutorials tutorialsRuntime)
```

The `allTutorialSplices` can now be added to our top level HeistConfig so it
will be available whenever we render the tutorials template:

```haskell
app :: SnapletInit App App
app = makeSnaplet "app" "A snap demo application." Nothing $ do
    h <- nestSnaplet "" heist $ heistInit "templates"
    -- add the compiled splices to our HeistConfig
    addConfig h $ mempty { hcCompiledSplices = allTutorialSplices }
    -- the rest of your SnapletInit
```

At this point all that remains is creating a Snap handler to render our
template:

```haskell
loopHandler :: Handler App App ()
loopHandler = cRender "tutorials"
```

Note again that unlike interpreted splices, we don't provide any local splices
specific to the template. When the template is rendered, it will find those
splices in our HeistConfig.

Note that the above example is a simplified version of the working, annotated
code available
[here](https://github.com/ericrasmussen/snap-heist-examples/blob/master/src/handlers/LoopCompiled.hs).


#### Is it worth it?

The big question for me right now is whether the apps I'm working on would
benefit the most from interpreted or compiled Heist. I definitely find it easier
to think in terms of interpreted splices, and normally I advise against
premature optimization.

However, in this case there are two factors that have me going down the compiled
road:

1. The speed difference really is that dramatic, and
2. Porting interpreted to compiled is not trivial

Using compiled Heist requires a very different mindset. If you suspect you may
ever need the performance benefits, it's likely worth your time to invest in
structuring your code and templates around compiled from the beginning.

The unexpected benefit to this approach is being forced to consider upfront
how you produce data and expose it to templates, which at least for me has me
wanting to instinctively minimize the number of top level splices.

There are some caveats with compiled Heist of course. Some are shared with
interpreted Heist: because templates are treated as data rather than code, you
can get runtime errors if you remove or modify templates (this is intentional:
the upside is you don't need to recompile to modify your templates).

The only new caveat is that since you can't express the notion of "render this
template with this specific set of splices", you have to be careful to make sure
you don't reuse node names at the top level. For instance, if you have one type
of `<userEmail>` node in a profile template, and another in an account
management template, your top level config will gladly accept both (no compile
time errors) but only retain one, possibly leading to confusing errors.

I do not think it is difficult to avoid a problem like this, but in larger
projects it definitely requires care and thought.


#### More examples and tutorials

I updated my [snap-heist-examples
repo](https://github.com/ericrasmussen/snap-heist-examples) repo with comparable
compiled versions of the original interpreted examples. It's not a bad place to
start if you want to see Heist used in the context of a Snap application, and it
should be relatively straightforward to clone the repo and build the app locally
if you need a playground for learning Snap and Heist.

Here are some additional resources for getting started:

* [Heist Template Tutorial](http://snapframework.com/docs/tutorials/heist)
* [Compiled Splices Tutorial](http://snapframework.com/docs/tutorials/compiled-splices)
* [Attribute Splices Tutorial](http://snapframework.com/docs/tutorials/attribute-splices)
* [Compiled Heist insight, with no Snap in sight](https://www.fpcomplete.com/school/to-infinity-and-beyond/older-but-still-interesting/compiled-heist-insight-with-no-snap-in-sight)
* [The Great Template Heist](/posts/the-great-template-heist.html)


<hr />

<sub><a id="footnote1">1.</a> Details available in the [original
announcement](http://snapframework.com/blog/2012/12/9/heist-0.10-released)</sub>

