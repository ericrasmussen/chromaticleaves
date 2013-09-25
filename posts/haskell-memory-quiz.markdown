---
title: Striving for Correctness: A Case Study
date: 2013-09-25
tags: code, haskell
metadescription: A case study in using Haskell for the command-line utility hsmemoryquiz
---


The most generic definition of confidence in your code is "code that does what
you think it does". No easy task. In a codebase of even modest size, there is
far too much room for flawed assumptions, edge cases, and other unexpectations.
Programmers seem to agree that gaining confidence in your code is
desirable, and there have emerged at least two broad categories of solutions:

#. Types
#. Tests

Many inflammatory posts and twitter arguments have framed these camps as
Types *versus* Tests, but the two aren't mutually exclusive. If you've read my
post on [Making Code Reasonable](/posts/making-code-reasonable.html), you may
correctly guess that I prefer types, but I write tests (albeit for different
purposes) either way.

Proponents of dynamic languages<sup>[1](#footnote1)</sup> are frequently taught
to solve problems in ways that can only be checked with tests, and this
particular style of problem solving is one of the fundamental disconnects
between the types and NoTypes crowds. Ask one of these people (including me!)
how often they've had to write extra unit tests to make up for the lack of a
good type system, and you're likely to be met with a confused look and a "why,
never!"

It's true that you won't find many tests in Python or JavaScript where the
programmers are explicitly inspecting the types of objects and secretly wishing
they had static typing, but this is missing the point. The benefit of static
typing isn't about enforcing the kinds of simple relationships that you wouldn't
test anyway, but expressing richer interactions that you can check with the
compiler instead of a test suite.

#### Case Study: hsmemoryquiz

Recently I had a somewhat frivolous project idea: a command-line program to
help me learn the Dominic System (a technique for increasing memory skills). An
explanation of the Dominic System and the program, hsmemoryquiz, are available
on [GitHub](https://github.com/ericrasmussen/hsmemoryquiz). We'll look at
some of the benefits of elevating data and abstractions to the type level.


##### Rethinking numbers and letters

The Dominic system is based on a mapping of the digits 0-9 to the letters
O, A, B, C, D, E, G, H, and N. This foundation gives you the building blocks for
working with all possible pairs of digits (00-99) and pairs of letters (OO-NN).

In many languages it would be practical (and expected) for you to model this
data with the primitives for integers and characters. But if you enjoy obsessing
over failure points in your program, this is unacceptable, because it means that
every function or method using these values would need to account for the
possibility of numbers outside the range 0-9.

Short of hideous, sprawling code with maddening error checking at every turn,
it's much more practical to define entry points for validating input before
passing it to the underlying functions. You can then narrow the scope of your
tests to those entry points and hope for the best.

But if we step back for a moment, we should be asking whether or not we need
the full power of integers, characters, strings, and all of the libraries and
built-ins capable of manipulating them.

Spoiler alert: we don't!

We can create new data types that contain only the values we need:


```haskell
data Digit = Zero | One | Two | Three | Four | Five | Six | Seven | Eight | Nine
  deriving (Eq, Enum)

data DigitPair = DigitPair Digit Digit
  deriving Eq

data Letter = A | B | C | D | E | S | G | H | N | O
  deriving (Show, Eq, Enum)

data LetterPair = LetterPair Letter Letter
  deriving Eq
```

In the Dominic system there is an exact mapping of Digits to Letters, and in
the Letter module of hsmemoryquiz we'll need a way to create Letters from
Digits. We can write a function with the following signature:

```haskell
fromDigit :: Digit -> Letter
```

This simple declaration gives us powerful reasoning tools:

* The function is total; given a value of type Digit, we can produce a value of type Letter
* We can enforce at compile time that fromDigit cannot be called with anything but a Digit
* No logic or tests required to check input, because by definition we only accept Digits

Now we can operate with complete confidence<sup>[2](#footnote2)</sup> that the
function does what we expect, and does so without affecting other parts of our
system. We've succeeded in pushing the need for validation further out, allowing
us to write a more robust core that doesn't need to consider the possibility
of bad input (and if anyone tries, the program won't compile).

#### Control flow and staircasing

Inevitably we will need to face the outside world, and types afford us many
tools for combating bad input. In imperative languages, it's common to ignore
certain kinds of troublesome input and instead throw exceptions when things go
awry. This is a pattern that is convenient to write, but complicates the flow of
our programs. There is an added mental overhead in having to know which
exceptions may be thrown and where they may or may not be caught.

Often we can obviate the need for exceptions by returning values that indicate
some failure condition instead. The problem here is that if you have many values
that work this way, you can end up with long, complicated code blocks. Let's
look at an example in python where any of the arguments may be a legitimate
value or *None*:

```python
def build_registry(foo, bar, baz):
    if foo is not None:
        if bar is not None:
            if baz is not None:
                return Registry(foo, bar, baz)
    return None
```

Now you can see why exceptions are so appealing here! It's much simpler to try
to make an instance of Registry and ask for forgiveness (in the form of a
try/except block) than it is to constantly validate input. In many languages and
frameworks the notion of an empty or bad value may vary as well, requiring you
to sometimes check for null, undefined, empty strings, lists with a length of 0,
etc.

What we're really missing in these languages is a way to express values that may
be more than one type. In Haskell we can achieve this with algebraic data types.
One of the canonical examples is:

```haskell
data Either a b = Left a | Right b
```

We can use this to unambiguously signify error conditions with the Left
constructor and valid values with the Right. This would even allow us to define
a concrete type Either String String and reliably differentiate the two cases
without resorting to string matching, checking for null values, or checking for
an empty string.

More importantly, we can use this as a basis for richer types that
carry the notion of success or failure cases with them, rather than requiring
the use of exceptions. Here's an example from the Game module in hsmemoryquiz
that runs a continuous quiz game:

```haskell
playGame :: Quiz ()
playGame = do
  assoc <- nextAssociation
  res   <- playRound assoc
  case res of
    Continue -> playGame
    Stop     -> return ()
```

The Quiz moand stack includes ErrorT, which means that any time we run a
computation in the Quiz monad (in this case, the first two lines in the *do*
block), the value returned may be either an error or a valid value.  There's no
need to alter the flow of the program or nest a long series of conditionals,
because the types extracted from Quiz computations already carry that notion of
failure with them. If the nextAssociation function is unsuccessful (i.e. it
returns ErrorT's Left case), then the playRound line will not be evaluated, and
the entire block will evaluate to that Left case.

The function that runs the game can then pattern match on the final value to
differentiate the two cases:

```haskell
runGame :: Registry -> IO ()
runGame registry = do
  putStrLn "Welcome! Quit at any time with \":q\" or by pressing ctrl-c"
  res <- runQuiz registry newQuizState playGame
  case res of
    (Left  e, q) -> putStrLn $ formatError e q
    (Right _, q) -> putStrLn $ formatSuccess q
```


### A twist ending

Although I am very certain all of you will want to dedicate hundreds of hours to
learning obscure memory techniques and practicing them with my program, the real
motivation behind [hsmemoryquiz](https://github.com/ericrasmussen/hsmemoryquiz)
was creating a fairly straightforward example of a Haskell command-line utility
with several nice touches:

* Lots of code comments
* Command-line flag parsing
* Error handling through types
* QuickCheck test examples using hspec
* An interactive prompt via Haskeline (including interrupt handling)

There are of course plenty of great resources out there for learning Haskell,
and this isn't intended to be a canonical example of How to Write Haskell; there
are much better and more interesting Haskell programs<sup>[3](#footnote3)</sup>.

But many full-featured utilities and programs are not written with beginners in
mind. If you find yourself writing a lot of smaller utilities or single-file
Haskell examples but haven't quite taken the next step, I hope this will help
you on your way.


<hr />

<sub><a id="footnote1">1.</a> "Dynamic" being a somewhat contentious term, used here to roughly mean "types that are checked at runtime"</sub>

<sub><a id="footnote2">2.</a> Modulo the usual caveats (unsafePerformIO, error, non-termination)</sub>

<sub><a id="footnote3">3.</a> A short list of programs that have inspired me: xmonad, hlint, hoogle, hakyll</sub>
