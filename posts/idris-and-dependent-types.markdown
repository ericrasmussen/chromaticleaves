---
title: White paper: Compile Time TDD Coverage with Idris
date: 2014-05-03
tags: code, idris
metadescription: A high level introduction to learning dependent types via Idris
---

Recent research-based advances in computering have shown that people want more
TDD and expend most of their time coming up with components of code called
"units" so that they can test them for quality assurance.

But guess what?

> *They're doing it. Wrong.*

A crack team of compiler inventors has been in stealth mode for literally
months preparing a new way to TDD without having to make up units all the time.

The Idris compiler (industry buzzword for a linting tool) is so advanced you can:

* check all the dynamic types just once at compile time
* evaluate all possible test cases before the code even runs
* help the compiler write tests before you even write the code


#### How the breakthrough works

Have you ever written code to access an array index and you just *knew* it
wouldn't fail, but you still had to account for that possibility? In the
early days of computing (circa 2009 when node.js was created) everyone tried
to make up for this uncertainty by writing unit tests.

But the Idris compiler doesn't mess around: you can just say it won't fail, *so
it won't*.

This is made possible through the magic of dependent types, a type of type even
more dynamic than dynamic types, because they let types depend on values.
Types are no longer mindless declarations like Int or String or Whatever in
dependent typing. You can have particular values, non-empty containers,
and more complex relationships all inside the type signature.

Behold, examples:

```
-- tell the compiler that concatenating vectors of size n and m makes a new
-- vector of size n + m. The compiler checks the cases for you!
concatVectors : Vect n a -> Vect m a -> Vect (n + m) a

-- repeat values of some type "a" `n` many times in a vector. The size of the
-- returned vector is guaranteed to be the size of `n`
replicate : (n: Nat) -> a -> Vect n a

-- no out of bounds access here! you can only look up an index in a vector of
-- size `n` if you call it with a number between 0 and `n`
index : Fin n -> Vect n a -> a
```

Best of all: the dynamic checks only happen once before your program ever
runs!

This works through a process known as mathematical proofing, where the compiler
knows enough about your code to ensure coverage instead of just guessing at it
with a handful of tests. If you try to express something the compiler doesn't
know how to check already, you can switch to an interactive theorem proving
mode, letting you dynamically solve problems before the code ever runs.

Let's recap. Idris and dependent types make it possible to:

1. Write type signatures that depend on values
2. Enforce those relationships at compile time instead of runtime
3. Write proofs to show you can only create/modify data in ways that preserve
   those relationships



#### Interactive proving

Imagine you're building a next gen full stack web app where users can earn and
redeem special tokens whenever they recommend your app to a friend. You want to
make a stack-like structure that lets you track the number of recommendations
and the number of redemptions, but always ensure the number of redemptions is
less than or equal to the number of recommendations (in Idris, the type for
a relation `n <= m` is `LTE n m`).

First you define some data:

```
data User = MkUser String

data Redeem = MkRedeem Int

data Earn = Recommend User

Action : Type
Action = Either Redeem Earn

data History : Type where
  MkHist :  (user     : User)               ->
            (redeemed : Nat)                ->
            (offset   : Nat)                ->
            (earned   : Nat)                ->
            LTE (redeemed + offset) earned  ->
            Vect (redeemed + earned) Action ->
            History

```

We know that our users can always recommend the app to friends, so let's write
a function to update their history when they make a recommendation:

```
recommendApp : History -> User -> History
recommendApp (MkHist u r o e p v) friend =
  MkHist u r (S o) (S e) p v'
    where a  : Action
          a  = Right $ Recommend friend
          v' : Vect (r + (S e)) Action
          v' = rewrite (sym $ plusSuccRightSucc r e) in a :: v
```


Anytime you see something of type `Nat` (a natural number, or a whole number
greater than or equal to 0), you can take the successor of that number with `S`.
For any natural number `n`, `S n` is equivalent to `n + 1`.

But when you run this, Idris finds an issue!

```
Can't unify
        LTE (plus r o) e
with
        LTE (plus r (S o)) (S e)

Specifically:
        Can't unify
                e
        with
                S e
```

It's telling us that having proved `(r + o) <= e` isn't the same as
proving `(r + o + 1) <= e + 1`. Notice how Idris came up with this test all on
its own even though we didn't write any units!

But if we have a valid `LTE` relationsip then it's pretty clear you can add
one to each side and show the relationship holds.

This is where dynamic testing comes in. Except instead of writing a bunch of
unit tests in a separate file somewhere you can just put a variable with a
question mark right in your code to show we have no idea what we're doing.
Idris calls variables prefixed with a question mark "metavariables", and by
convention we use *?wtf*, *?notagain*, or *?sendhelp*.

```
recommendApp : History -> User -> History
recommendApp (MkHist u r o e p v) friend =
  MkHist u r (S o) (S e) ?wtf v'
    where a  : Action
          a  = Right $ Recommend friend
          v' : Vect (r + (S e)) Action
          v' = rewrite (sym $ plusSuccRightSucc r e) in a :: v

```

Now if you load this up in the Idris interpreter and enter the command `:p wtf`
it will tell you what it is you're trying to do, even if you were just making
things up. We'll also type `intros` to have it take all of the arguments as
givens and show us what we're solving for (the goal):

```
-main.wtf> intros
----------              Other goals:              ----------
{hole6},{hole5},{hole4},{hole3},{hole2},{hole1},{hole0}
----------              Assumptions:              ----------
 u : User
 r : Nat
 o : Nat
 e : Nat
 p : LTE (plus r o) e
 v : Vect (plus r e) (Either Redeem Earn)
 friend : User
----------                 Goal:                  ----------
{hole7} : LTE (plus r (S o)) (S e)
```

If we know that `p = LTE (plus r o) e` is a given, one way to solve the goal is
to show that `LTE (plus r (S o)) (S e)` can be rewritten as `p`. But it's kind
of hard to do that without first breaking down `plus r (S o)`, so let's rewrite
it in the form `S (r + o)` instead.  There's a built-in proof called
`plusSuccRightSucc` that lets us do just that, so we'll use the `rewrite`
tactic:

```
-main.wtf> rewrite (plusSuccRightSucc r o)
----------              Other goals:              ----------
{hole7},{hole6},{hole5},{hole4},{hole3},{hole2},{hole1},{hole0}
----------              Assumptions:              ----------
 u : User
 r : Nat
 o : Nat
 e : Nat
 p : LTE (plus r o) e
 v : Vect (plus r e) (Either Redeem Earn)
 friend : User
----------                 Goal:                  ----------
{hole8} : LTE (S (plus r o)) (S e)
```

Notice how the goal has been updated for us based on the rewrite.

Now if only we had a way to prove that `LTE n m` implies `LTE (S n) (S m)` we
could solve for this. Good news! The very definition of `LTE` contains a
constructor `lteSucc` that proves just this. We'll use the `mrefine` tactic
to rewrite the relationship for us (unlike `rewrite`, `mrefine` will use
pattern matching so we don't need to supply the variables explicitly):

```
-main.wtf> mrefine lteSucc

----------              Assumptions:              ----------
 u : User
 r : Nat
 o : Nat
 e : Nat
 p : LTE (plus r o) e
 v : Vect (plus r e) (Either Redeem Earn)
 friend : User
----------                 Goal:                  ----------
{__pi_arg516} : LTE (plus r o) e
```

If the goal you're solving for is in the same form as one of the assumptions,
you can use the `trivial` tactic to complete the proof, and `qed` to see
the results:

```
-main.wtf> trivial
wtf: No more goals.
-main.wtf> qed
Proof completed!
main.wtf = proof
  intros
  rewrite (plusSuccRightSucc r o)
  mrefine lteSucc
  trivial
```

We need this proof in our source file, but having to copy and paste is the kind
of thing we did in the early 2010's, and that doesn't cut it anymore. After
entering `qed` for a solved proof, you can use `:addproof` to have it
automatically appended to your source file.


#### Conditional proofs

So far so good! But we said users can only redeem tokens if they have made
enough recommendations to other users, and that's something we can only know at
runtime. [Idris](http://en.wikipedia.org/wiki/Ivor_the_Engine#Idris_the_Dragon)
might be magic, but even Idris can't predict the future.

We might first think to write a function with type `History -> Redeem ->
History`, but it's impossible to redeem a token if a user doesn't have enough
recommendations, and those values are only known at runtime. So let's try
`History -> Redeem -> Maybe History` instead, and it'll look a little something
like:

```
redeemToken : History -> Redeem -> Maybe History
redeemToken (MkHist _ _ Z     _ _ _) _     = Nothing
redeemToken (MkHist u r (S o) e p v) token =
  Just $ MkHist u (S r) o e ?redeemPrf (Left token :: v)
```

Remember that weird looking offset value we carry around in the `History` type?
It's time to put it to use! If we didn't have an offset we'd only ever know
that we had a number of redeemed tokens less than or equal to the number of
earned tokens, and `r <= e` isn't enough information to prove `r + 1 <= e`.

The offset lets us rewrite everything as `r + o <= e`. If `o` is 0 (the natural
number `Z`) then the problem reduces to `r <= e` and can't be solved. But if `o`
is greater than 0 then we can always rewrite `r + (o + 1)` as `(r + 1) +
o`. This lets us increase the count for redeemed tokens and the size of our
history vector, while always enforcing we'll never have more redeemed tokens
than earned tokens.


Writing the `?redeemPrf` is a fun exercise, or you can see a full, working
example of the code in this
[gist](https://gist.github.com/ericrasmussen/8173956196158e39c716).


#### Not convinced?

Writing correct software and only having to check things once means efficiency,
and efficiency means *success*. And money. Mostly money.

The cost of efficiency is having to know what you want to write before you write
it, and our findings have shown this is a useful property in software
development despite conventional wisdom.

In the preceding example we showed that you can make a data structure correct by
construction: if you can't show you're doing it right, you can't construct an
instance of it. Imagine all the hours we just saved from writing TDD driven
tests!  Idris just let us interactively write one big test that only has to run
once before your program runs, and all the test cases are covered there on out.

This might be a silly example, but imagine a world where crypto libraries can't
fail due to bounds checks.

Imagine it.



#### Sign me up!

Get started with this amazing new technology by installing the [Haskell
Platform](http://www.haskell.org/platform/) (if you don't have GHC and
cabal-install on your system already), and running the commands:

```console
cabal update
cabal install idris
```

You can read more detailed instructions for different operating systems on
the [Idris wiki](https://github.com/idris-lang/Idris-dev/wiki).

Now you can work through the tutorial on the
[docs](http://www.idris-lang.org/documentation/) page to learn more!

