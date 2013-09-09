---
title: Thoughts on Functional Javascript
date: 2013-09-08
tags: code, javascript
metadescription: A quick review of Functional Javascript by Michael Fogus
---

I have long struggled with the necessity of JavaScript and the pain it brings,
and was naturally very interested in what Michael Fogus's new book had to offer.
[*Functional JavaScript*](http://shop.oreilly.com/product/0636920028857.do) is a
book that appears to serve two very different goals:

#. teaching functional programming to JavaScript programmers
#. teaching JavaScript programming to functional programmers

Balancing the two is no easy task, but Fogus guides the reader expertly, never
dwelling so long on a particular concept as to disengage readers from one camp
or the other. I approached the book from a functional background, but was
surprised at how much I learned from Fogus's explanation of functional concepts
in the context of a language that doesn't have native support for my favorite
abstractions.

The biggest selling point for *Functional JavaScript* is the book finds a way to
combine the two more elegantly than I could have imagined. I was about ready to
give up on vanilla JavaScript and move on to an altJS
language<sup>[1](#footnote1)</sup>, but Fogus has helped restore some of my
faith in being able to write reasonable software in JavaScript despite its
failings. This is a good thing, since we'll be stuck with it for the foreseeable
future<sup>[2](#footnote2)</sup>.


#### Functional Interfaces

As a functional programming evangelist (read: someone who talks way too much
about functional programming), one of the most common questions I get from
object oriented (OO) programmers is how you can reuse code without
objects. There's a table for that:

| Language   | Code Reuse via                                         |
-------------+--------------------------------------------------------|
| Haskell    | Types                                                  |
| Scala      | Types                                                  |
| OCaml      | Types                                                  |
| JavaScript | *mumbles about higher order functions and composition* |

Fogus's answer, it turns out, is a whole lot better than mine. He guides the
reader through building functional APIs that can:

* minimize state (using purity where applicable)
* leverage functions as units of abstraction (encapsulation)
* write property-based tests for impure functions
* view programs in terms of data flow (pipelines)

The examples used throughout the book are illustrative and concise. He even
manages to build functions for currying and partial application that look and
feel like the functional abstractions I know and love, without mangling
JavaScript to do it.


#### Embracing the Craziness

Whenever I write JavaScript I have to tread carefully and silently rage at HOW
DO YOU PEOPLE PROGRAM THIS WAY. JavaScript offers limitless ways to shoot
yourself in the foot, and is missing a number of constructs I find it
increasingly difficult to program without, including algebraic data types. To
avoid the error prone nature of manually managing inputs and outputs that can be
many different types of objects, I typically create restrictive APIs that only
expect and return well-defined objects or classes of objects.

Many of Fogus's examples run contrary to my intuition here, and fully embrace
JavaScript's ability to pass around objects of any type. The book's samples are
meant to be illustrative of course, but you will see examples like a [*flat*
function](https://github.com/funjs/book-source/blob/bdea86177e3c8b5ab2d27de7e79deb74b1f72b38/chapter06.js#L134)
that is designed to take an array and recursively flatten any arrays it
contains. The consequence of course is that the function's sole parameter,
*ary*, will sometimes be a non-array value that needs to be returned as an
array.

But setting aside my usual predilections, if you squint hard enough, you can see
the values as sum types and accept this as a very reasonable and flexible way to
write flexible JavaScript code. There is certainly no question that it works, is
understandable, and takes better advantage of JavaScript than my usual rigid
adherence to pretending the issue doesn't exist.

Many of the other chapters focus on collections-based programming with higher
order functions, leveraging primtive types, and encapsulation through
functions. Fogus also answers the question of how to take advantage of objects
without giving into inheritance, and he manages to weave an object compositional
style (mixins) with a functional API in a very slick way.


#### Libraries

I would have liked to see more on how to use these ideas to build rich user
interfaces, but there's a lot of disagreement on that topic in general, and it's
an open problem for the functional community. However, even though it's not a
central idea for the book (nor should it be), Fogus takes care in the appendix
to touch on several alternative libraries and altJS languages.

*Functional JavaScript* primarily uses [underscore.js](http://underscorejs.org/)
in its examples. The ideas in the book are in no way dependent on the library,
but it offers stable implementations of many higher order and collections-based
functions to make the functional programmer feel at home. As nice as it is to
not have to write *for loops* for everything, underscore.js isn't quite what I'm
looking for in a functional library, but there's no real consensus or widely
accepted library for the displaced functional programmer writing JavaScript.
Next on my list is giving [allong.es](http://allong.es/try/) a go to see if it
addresses some of my personal issues (which, in any case, would be quite a
feat).


#### (function conclusion () {

If you write JavaScript, read
[this book!](http://shop.oreilly.com/product/0636920028857.do)

You'll learn a lot about writing clean, maintainable code that is applicable to
any imperative language, but especially encouraging for JavaScript, a language
that is easily, and frequently, abused.

#### })()

<hr />

<sub><a id="footnote1">1. </a>Any language that compiles to JavaScript.
There's a nice list at [altjs.org](http://altjs.org).</sub>

<sub><a id="footnote2">2. </a>Largely on the web, but expect the list of non-web
uses on [Wikipedia](https://en.wikipedia.org/wiki/JavaScript) to continue
growing.</sub>