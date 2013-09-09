---
title: Thoughts on Functional Javascript
date: 2013-09-08
tags: code, javascript
metadescription: A quick review of Functional Javascript by Michael Fogus
---


JavaScript is the language we love to hate. At least, I do. And if you're
reading this, I'm going to guess you do, too. But as you also know, we're very
much stuck with it for the foreseeable future<sup>[1](#footnote1)</sup>.

I have long struggled with the necessity and pain of the language, and was
naturally very interested in what Michael Fogus's new book had to offer.

[*Functional JavaScript*](http://shop.oreilly.com/product/0636920028857.do) is a
book that appears to serve two very different goals:

#. teaching functional programming to JavaScript programmers
#. teaching JavaScript to functional programmers

Balancing the two is no easy task, but Fogus guides the reader expertly, never
dwelling so long on a particular concept as to disengage readers from one camp
or the other. I approached the book from a functional background, but was
surprised at how much I learned from Fogus's explanation of functional concepts
in the context of a language that doesn't have native support for my favorite
abstractions.

I've struggled with how to reconcile functional programming and JavaScript
before. There are countless approaches you could take, but finding one that
makes sense in the context of JavaScript and still gives you the benefits of
functional programming is not trivial. The biggest selling point for
*Functional JavaScript* is that the title is not only accurate, but the book
combines the two seemingly disparate notions much more elegantly than I could
have expected.

To put it more bluntly, I was about ready to give up on vanilla
JavaScript and move on to an altJS language<sup>[2](#footnote2)</sup>, but Fogus
has helped restore some of my faith in being able to write reasonable software
even in JavaScript.


#### Functional Interfaces

As a functional programming evangelist (read: someone who talks way too much
about functional programming), one of the most common questions I get from
object oriented (OO) programmers is how to make code reusable. When I'm asked
about code reuse in Haskell, I answer, simply: types.

When I'm asked about functional code reuse in JavaScript, I answer, less
simply: higher order functions, composition, and... can we not use JavaScript,
please?

Fogus's answer, it turns out, is a whole lot better than mine. He guides the
reader through building a functional API to:

* use pure functions where possible
* leverage functions for encapsulation
* use property based testing for impure functions
* view programs in terms of data flow/pipelines

He even manages to build functions for currying and partial application that
look and feel like the functional abstractions I know and love, without mangling
JavaScript to do it.


#### Embracing the JavaScripts

But there's undeniably a lot we have to give up in a language that does not put
safety first. It can be difficult to let go of constructs I find it increasingly
difficult to live with out, like polymorphic types, algebraic data types, and
so on. When I find myself stranded in a language that encourages programmers
to shoot themselves in the foot, I have to tread carefully and silently rage
at HOW CAN YOU PROGRAM THIS WAY OMG.

One of my biggest stumbling blocks has been trying to let go of types. In a
language with algebraic data types, it's perfectly reasonable to have function
arguments or return values that can be more than one type, because the language
typically gives you ways to enforce those relationships and cover all cases.
When I don't have that, as in JavaScript, I have tried to avoid the issue by
creating APIs where each function argument or return value has a single expected
type.

Many of Fogus's examples run contrary to my intuition here, and fully embrace
JavaScript's ability to pass around objects of any type. The book's examples are
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
adherence to pretending the issue doesn't exist. If you love your sum types
though, we can still take a moment to lament their absence in JavaScript.

Many of the other chapters focus on collections-based programming with higher
order functions, leveraging primtive types, and encapsulation through
functions. The question for me, as a functional programmer who knows OO, is when
do I give in and write OO style code instead? One of Fogus's answers is avoiding
inheritance APIs and using object composition via mixins, and he successfully
weaves them into a functional API in a very slick way. You'll have to
read his book to see how.


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
not have to write for loops for everything, underscore.js isn't quite what I'm
looking for in a functional library, but there's no real consensus or widely
accepted library for the displaced functional programmer writing JavaScript.
Next on my list is giving [allong.es](http://allong.es/try/) a go to see if it
addresses some of my personal issues (which, in any case, would be quite a
feat).


#### function conclusion () {

If you write JavaScript, read
[this book!](http://shop.oreilly.com/product/0636920028857.do)

You'll learn a lot about writing clean, maintainable code that is useful in
general, but particularly surprising given a language that is easily, and
frequently, abused.

#### }()

<hr />

<sub><a id="footnote1">1. </a>Largely on the web, but expect the list of non-web
uses on [Wikipedia](https://en.wikipedia.org/wiki/JavaScript) to continue
growing.</sub>

<sub><a id="footnote2">2. </a>Any language that compiles to JavaScript.
There's a nice list at [altjs.org](http://altjs.org).</sub>