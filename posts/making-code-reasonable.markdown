---
title: Making Code Reasonable
date: 2013-08-28
tags: code, haskell, soapbox
metadescription: A brief intro to forthcoming articles on using types to increase confidence in code
---

By day I spend most of my time working with object oriented languages such as
Python and Javascript, and I have identified two boundless sources of
frustration:

#. It's very difficult to reason about the code
#. Test suites are insufficient for building code confidence

To the first point, I think Joel Spolsky puts it best: "It’s harder to read code
than to write it."<sup>[1](#footnote1)</sup>

This is especially true in languages where anything can happen at any
time. Let's take a look at a small Python snippet:

```python
import foo

def bar(baz, quux):
    x = baz.do_something()
    y = quux.do_something_else()
    return x + y
```

In the absence of meaningful variable names and documentation, what can we
assert about this example?

Unfortunately, very little. Let's look at an annotated version to see why:

```python
# imports can have side effects, like writing to files or launching missiles
import foo

def bar(baz, quux):
    # baz can be *any* object and may not have a do_something() method
    x = baz.do_something()
    # quux can be *any* object and may not be able to do_something_else()
    y = quux.do_something_else()
    # the plus operator can be overloaded and could do something unpredictable
    # or fail outright
    return x + y
```

And that's only scratching the surface. It's entirely possible that baz and quux
are modifying some shared state, and if we don't call them in order, we'll face
imminent meltdown. Maybe one of the methods has an obscure condition that tells
it to return a string every second Tuesday, but integers the rest of the time.

Feel free to ponder additional unforeseen problems: bar called with one or more
None arguments or the wrong number of arguments, methods on baz or quux hitting
the file system, modifying a database, raising exceptions or abruptly
terminating your program, etc. Considering all the possibilities and trying to
account for them is an exercise in madness-inducing futility.

In 2006 Tim Sweeney of Epic Games gave a talk on the future of game
development<sup>[2](#footnote2)</sup>, in one slide demonstrating all the possible runtime
failures in a C# snippet:

![](/images/epic-fail.png "Tim Sweeney on Game Dev")

This brings us back to the original point: it's often easier to write code than
read it, because reading it communicates so very little about what it actually
does or what may go wrong when it runs. Many of us have been bitten before by
fragile code with subtle dependencies, shared global state, and worse. Even many
popular open source libraries occasionally engage in bouts of inspired insanity.


#### Mitigating the unknowns

These problems are not unique to Python, but in the Python community we try to
compensate for them in various common ways:

#. Meaningful variable names
#. Documenting expected inputs, outputs, and possible exceptions
#. Conventions/idioms that are recognizable to other Python programmers
#. Linters
#. IDEs/code intelligence
#. Test suites

And that brings us full circle back to pet peeve #2: although I am very ardent
about writing tests, thinking about them too deeply is terrifying. Once you
start to consider reducing dependencies in units of code, defensive coding
practices, and covering all possible inputs and outputs, it becomes clear that
you can't.  Going down the rabbit hole only helps you discover more and more
potential points of failure.

Which all leads us to the number one way programmers address these issues
in imperative languages: *Optimism*.

In the face of limitless and uncontrollable chaos, what else can we do but
ignore it and march on with the best of intentions? Test suites give us a way
to mitigate the most common issues (along with aiding longterm maintenance and
helping to prevent regressions), but they can only do so much to give us
confidence that our code is correct.


#### Alone in my ivory tower

The astute among you may call attention to all of the high quality imperative
code out there. The well-managed projects that survive day after day of grueling
production use, realizing the dream of extensibility with new features and rapid
but stable development cycles. If this code is really so fragile, then how is
it people can Get Things Done<sup>TM</sup>?

Certainly you can write robust code in many languages, despite the limitations
and potential failings I've pointed out. But it's also undeniable that these
issues manifest in the form of subtle bugs, libraries that interact in confusing
and unexpected ways, and a whole lot of headaches in trying to reconcile bad
behavior.

To make it worse, the argument that this approach is "practical" or "real world
scale" is often used to dismiss the idea that other paradigms can
achieve a greater level of safety in a comparable amount of code.

I'm tempted to call this the Java Effect, in honor of all those poor souls who
associate static typing with Java's poor implementation of types. Writing types
should not be a hindrance or a chore that leads to vast swaths of boilerplate
and redundancy, but a way to be more expressive and
accurate in the code you write. Assuming one bad experience with static typing
is representative of all static typing is like assuming every implementation of
OO is the same.

*"Oh, you write ruby? I don't OO because java."*


#### Safety first

I want to write code that people would rather read and use than rewrite. There
are many barriers to achieving that goal that extend well beyond the scope of
the current discussion, but portions of it are within our reach.

Let's revisit the earlier Python example with a similar example, this time in
Haskell:

```haskell
import Foo

bar :: Baz -> Quux -> Int
bar baz quux = doSomething baz + doSomethingElse quux
```

We can see immediately that in comparison, Haskell code scales horizontally
whereas Python scales vertically. But even more important: we know that there
are no effectful computations. No state will be harmed during the execution of
this function.

The type signature not only conveys information, but also forms a
proposition: given a Baz and a Quux, we can prove that the function
*bar* will produce an Int.<sup>[3](#footnote3)</sup>

Digging deeper, we can even infer that doSomething has the type Baz -> Int, and
doSomethingElse has the type Quux -> Int.

We've learned these things by examining only the types, and with a sufficiently
advanced type system like Haskell's, we can distinguish between pure and
effectful computations based on the type signature alone. If *bar* had the
capability to engage in IO, it would be reflected in its return type.

There are some properties that are difficult or impossible to enforce at the
type level<sup>[4](#footnote4)</sup>, so even in this model there is still room
for testing as a way to gain confidence in our code. Typically, however, the
tests will focus on establishing and attempting to enforce the properties we
expect the code to have. This lets us throw barrels full of randomly generated
data at our functions instead of having to contrive a handful of unit test cases
that might seem really cool at the time, but ultimately give a false sense of
security.

#### Tell me more about these... types

There are actually several languages that offer nice type systems, including
SML, OCaml, and Scala. But since I'm the most familiar with Haskell, I'll go
ahead and recommend you start here:

* [Learn You a Haskell](http://learnyouahaskell.com/)
* [Real World Haskell](http://book.realworldhaskell.org/)
* [Haskell Wiki Book](http://en.wikibooks.org/wiki/Haskell)

There's also no dearth of blog posts and tutorials aimed at programmers coming
from specific languages or paradigms. Try searching "haskell for &lt;insert
language here&gt; programmers" to discover your personalized copy today.

But even though we have these great resources for learning the Haskell
*language*, many of them don't discuss how to build a Haskell *application* from
start to finish, including build files, tests, documentation, and code layout.

I am working on a small command line application to demonstrate many of these
ideas and serve as a relatively straightforward but complete example. The goal
will be to make it illustrative and add comments and annotations to reflect on
possible alternative approaches, which is often an impractical level of
documentation for programs intended to be used by people to do things.

The project will also favor code confidence over code conciseness or code
celerity<sup>[5](#footnote5)</sup>. All the while still making a working, and, dare I say it,
reasonable application. Stay tuned!

<hr />

<sub><a id="footnote1">1.</a> From [Things You Should Never Do, Part I](http://www.joelonsoftware.com/articles/fog0000000069.html)</sub>

<sub><a id="footnote2">2.</a>Links to Tim Sweeney's excellent presentation
available in [PPT](http://www.cs.princeton.edu/~dpw/popl/06/Tim-POPL.ppt) and
[PDF](http://groups.csail.mit.edu/cag/crg/papers/sweeney06games.pdf)

<sub><a id="footnote3">3.</a> See the [Haskell Wiki page](http://www.haskell.org/haskellwiki/Curry-Howard-Lambek_correspondence)
on types as propositions (and more).
</sub>

<sub><a id="footnote4">4.</a> Excepting the capabilities of dependently typed
languages</sub>

<sub><a id="footnote5">5.</a> Believe it or not, that's not the first time I've
used celerity in a sentence</sub>


