---
title: The Fool's Choice: A Tale of Two Types
date: 2014-02-28
tags: code, haskell, soapbox
metadescription: Exploring why mainstream programming misses the point of types
---

Imagine for a moment that programmers were constantly baited with snake oil:
paradigm shifts this way! Agile scrum productivity boost ahead! An IDE that will
astound you! A framework that solves the internets in only three lines of code!

Oh, that's right. We don't have to imagine.

But now imagine that, among all the noise, all the tools and frameworks created
for specialized use cases but recommended for all, lies something
useful. Something with the potential to change how you describe relationships
in code so you can make it correct by construction, not just assumed correct
by testing.

#### Types: not made of oil or snakes

A powerful way to achieve this is by using a rich type system, like those in
Haskell, Scala, and OCaml.

It's important to understand that these languages *will have issues*. No
programming language is the best language. None will be the language to end all
languages. The more you spend time using one of them for more and more
complicated use cases, the more likely you are to run into different types of
limitations.

But that's OK, because this post isn't about those languages. It's about
leveraging type systems to write better code. For the few people who like to
point out that these languages are experimental, or untested, or too academic,
however, I'd like you to keep this in mind:

* Haskell, Scala, and OCaml are all used in mission critical production systems
* They are proven to work just fine in "the real world"
* Learning types will make you a better programmer even if you use untyped
  languages


#### Choices

There's a group specializing in all kinds of leadership and skill building
techniques that uses the term
[Fool's Choice](http://www.crucialskills.com/glossary/#q27) to describe dilemmas
where you see a binary choice (either/or) instead of a multitude of options.

When it comes to people not wanting static types, this is the line of reasoning
I see:

1. Java has static types
2. In Java I have to name the type of every single thing exactly
3. This leads to a lot of boiiler plate
4. I don't even test types anyway!
5. Thus I can either use static types or no types (python/perl/ruby)

The options are sometimes seen as limited, cumbersome types or
no types at all.

So if you do understand static types through the lens of Java, or C/C++, or
similar languages, then I have a favor to ask. Imagine that everything you know
about static types is wrong. Imagine that what you've learned about them has
nothing to do with actual static types, but only the specific, broken
implementations of them that most of us are exposed to.

Do that, and I can tell you what static types are really about.


#### A motivating case

It's tempting to think of types as a way to declare the contents of a variable.
If I say the variable foo is an integer, you know the variable foo is an
integer. That might be helpful in some sense, but in dynamic languages you don't
need someone to tell you that "foo = 5" means foo is an integer. You're not
going to write tests asserting that foo is an integer, and indeed, you probably
aren't even going to think of it in those terms. You don't need to, after all.

But that's not very interesting. If you only see types as something that help
you declare the obvious and prevent simple bugs that you can check by eye or
make assertions about, of course you'll see no need for them. And in that case,
the productivity you get from writing in a language like python will absolutely
trump that of Java.

*Set yourself free from making meaningless declarations! Reduce the size of your
code! Simplify refactoring!*

So if we don't spend our dynamic language time testing types, what *do* we test?
Let's say you write a library function in python that takes any iterator and
writes the contents to file. In the true spirit of python, you don't care what
"type" of object someone passes in; anything that allows iteration is fine, and
of course you'd never want to limit yourself to only iterating over integers, or
strings, or whatever.

Now ask yourself: how do you make sure someone using your library calls
your function with an iterable?

#### Types to describe behaviors

In the above example, it's absolutely essential to your library's functionality
that someone only ever passes in an iterable, and you have no way of making sure
they do that. If they pass in something that doesn't allow iteration, everything
explodes.  You can decide to hope for the best (and when hope fails they'll see
a built-in exception that might be confusing), or explicitly check that they
pass in an iterator and raise a more meaningful exception.

But if you want to make sure your program behaves as expected, you'll need to
test it against both iterators and non-iterators to ensure the behavior is
correct.

What would be ideal here is a way to describe the behavior of your program at
the type level. Not to declare an exacting, exhaustive list of types that your
function accepts, but a whole *class* of types that can be used as iterators.

In Haskell, it'd look a little like this:

```haskell
writeLines :: Iterator a => a -> WriteFileAction
```

This reads as "we have a function named writeLines that takes an iterator of
any arbitrary type a, and produces an action that writes to a file."

This example is important: when you hear functional programming enthusiasts
saying type systems reduce testing, this is the kind of thing we mean. You've
just described a behavior that prevents anyone from trying to write to file with
your library unless they pass in an actual iterator. It's correct by
construction: try to call it with a non-iterator and it won't compile. You don't
need extra logic or tests to account for that possibility.

#### A hidden benefit

There's a big scary word we functional folk like to pass around called
parametricity. It has a very specific meaning and is covered in [many research
papers](http://www.haskell.org/haskellwiki/Research_papers/Type_systems#Parametricity),
but for our introductory purposes here we can say it's something that helps you
reason about what a function can or can't do by understanding how its properties
hold true for more than one type.

Let's look at our example one more time:

```haskell
writeLines :: Iterator a => a -> WriteFileAction
```

The syntax might be unfamiliar, but the definition tells us that we can ensure
the function is only called with an iterator. We don't care what that iterator
is.

But this tells us something else, too: if we don't know what the iterator is,
how it iterates, or what it contains, this function can't do anything *except*
iterate.

When your goal is reasoning about code and understanding it, it's not
possible to understate how huge this subtle implication really is. If we write a
function that holds true for all iterators, we can't do any non-iterator things
to it!

For instance, if someone calls it with a string iterator, we can't manipulate
the strings. How could we? If we wrote something specific to strings, the type
would be Iterator String -> WriteFileAction.

This gives us an unprecedented level of safety by ensuring the function will
only be able to make use of the iterator interface. When you are refactoring a
large program this makes it very easy to pull out sections of code and replace
them, because you know exactly what the code could or couldn't do.

Compare that to code that can do anything at anytime like raise exceptions or
manipulate shared state. I've even seen dynamic code that would iterate over
collections, check if the contents were a particular "type", like a string, and
tag something on to them. When those special cases can occur anywhere in an
untyped language, you always need to be on guard for them.


#### Taking the leap (not literally)

When we write code, especially code any other human (including your future self)
will need at some undetermined future point in time, we want some way to
tell that human how the code works.

If you have a rich type system, you're halfway there already. Docs get out of
date, test specifications are ill-specified, but types are forever. You get
the types right or your program doesn't compile. Want to write less tests?
Write more types. You only need tests to the extent that you don't have types.

And the hidden benefit to adopting this mentality (thinking in terms of correct
by construction) is it forces you to consider those same cases in untyped
code. It makes you all too aware of how quickly a piece of untyped code can fail
if someone passes in objects that don't fulfill some expected interface or
behavior.

If you start thinking in terms of the behaviors you want to describe and
enforce, it quickly gets you in the right state of mind for asking what happens
when that behavior can't be enforced. You can use that wariness to convey to
your users how it should work, you can state your expectations in the API and
narrative docs, and you can convey what will happen when that expectation isn't
met (an exception that gets raised, a function that returns some none or null
type, etc).

So my challenge to you is this: if you have not spent an extensive amount of
time working with a rich, expressive type system, spend some time [learning you
a Haskell](http://learnyouahaskell.com/). Learn it for fun, learn it for
something new, learn it to expand your mind, learn it for The Real World.
Whatever works best for you. But make an effort to understand just how
expressive you can be in writing code and how you can cut down on tests with
nicer types.