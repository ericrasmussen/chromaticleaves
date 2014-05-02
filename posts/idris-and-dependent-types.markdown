---
title: White paper: TDD supplanted by magic dragon
date: 2014-05-02
tags: code, idris
metadescription: A high level introduction to learning dependent types via Idris
---

Recent research-based advances in computering have shown that people want more
TDD and expend most of their time coming up with components of code called
"units" so that they can test them for quality assurance.

But guess what?

> *They're doing it. Wrong.*

A crack team of compiler inventors have been in stealth mode for literally
months preparing a new way to TDD without having to make up units all the time.

The compiler (industry buzzword for a linting tool) is so advanced you can:

* check all the dynamic types just once at compile time
* evaluate all possible test cases before the code even runs
* help the compiler write tests before you even write the code


#### How the breakthrough works

Have you ever written code to access an array indice and you just *knew* it
would always be there no matter what, but you had no way to ensure it? In the
early days of computing (circa 2009 when node.js was created) everyone wrote
unit tests to feel confident the code wouldn't fail.

But the Idris compiler doesn't mess around: you can just say it won't fail, *so
it won't*.

This is made possible through the magic of dependent types, a type of type even
more dynamic than dynamic types, because they let types depend on values.
Types are no longer mindless declarations like Int or String or Whatever in
dependent typing. You can have particular values, non-empty containers,
and more complex relationships all inside the type signature:

```
-- tell the compiler that concatenating vectors of size n and m makes a new
-- vector of size n + m. The compiler checks the cases for you!
concatVectors : Vect n a -> Vect m a -> Vect (n + m) a

-- repeat values of some type "a" `n` many times in a vector. The size of the
-- returned vector is guaranteed to be the size of `n`
replicate : (n: Nat) -> a -> Vect n a

-- no out of bounds access here! you can only look up an index in a vector of
-- size `n` if you look it up with a number between 0 and `n`
index : Fin n -> Vect n a -> a
```

Best of all: the dynamic checks only happen once before your program ever
runs!

This works through a process known as mathematical proofing, where the compiler
knows enough about your code to ensure coverage instead of just guessing at it
with a handful of tests. But sometimes even the compiler isn't enough, and
that's where the interactive theorem proving mode comes in. You can dynamically
solve problems before the code ever runs.

Let's recap. The tl;dr of dependent types is:

1. Write type signatures that depend on values
2. Write proofs to show you can only create and modify data in ways that make
   those relationships true
3. Success!


#### Interactive proving

Imagine you're building a next gen full stack web app where users can earn and
redeem special tokens whenever they recommend the app to a friend. You want to
make a stack like structure that lets you track the number of recommendations
and the number of redemptions, but always ensure the number of redemptions is
less than or equal to the number of recommendations.

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

Anytime you see something of type Nat (a natural number, or a whole number
greater than or equal to 0) you can take the successor of that number with S.
For any natural number n, S n is equivalent to n + 1.

We know that our users can always recommend the app to friends so let's write
a function to update their history when they make a recommendation:

```
recommendApp : History -> User -> History
recommendApp (MkHist u r o e p v) friend =
  MkHist u r (S o) (S e) p v'
    where e' : Action
          e' = Right $ Recommend friend
          v' : Vect (r + (S e)) Action
          v' = rewrite (sym $ plusSuccRightSucc r e) in e' :: v
```

But Idris has found an issue!

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

It's telling us that just because (r + o) <= e doesn't mean that (r + o + 1) <=
e + 1. But if we have a valid LTE relationsip then it's pretty clear that adding
one to each side doesn't change it.

This is where dynamic testing comes in. Except instead of writing a bunch of
unit tests in a separate file somewhere you can just put a variable with a
question mark right in your code to show we have no idea what we're doing.
Idris calls variables prefixed with a question mark "metavariables", and by
convention we use *?wtf*, *?notagain*, or *?sendhelp*.

```
recommendApp : History -> User -> History
recommendApp (MkHist u r o e p v) friend =
  MkHist u r (S o) (S e) ?wtf v'
    where e' : Action
          e' = Right $ Recommend friend
          v' : Vect (r + (S e)) Action
          v' = rewrite (sym $ plusSuccRightSucc r e) in e' :: v

```

Now if you load this up in the Idris interpreter it will tell you what it is
you're trying to do, even if you were just making things up. We'll also type
"intros" to have it take all of the arguments as givens and show us what we're
solving for:

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

If we know that p = LTE (plus r o) e is a given, one way to solve the goal is to
show that LTE (plus r (S o)) (S e) can be rewritten as p. But it's kind of hard
to do that with plus r (S o), so let's rewrite it into the form S (r + o)
instead.  There's a built-in proof called plusSuccRightSucc that lets us do just
that, so we'll use the rewrite tactic that says to rewrite particular variables
in some other form using another proof:

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

Now if only we had a way to prove that LTE n m implies LTE (S n) (S m) we
could solve for this. Good news! The very definition of LTE contains a
constructor lteSucc that proves just this:

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

If the goal you're solving for is in the same form as one of the assumptions,
you can use the "trivial" tactic to complete the proof, and "qed" to see
the results.

We need this proof in our source file, but having to copy and paste is the kind
of thing we did in the early 2010's, and that doesn't cut it anymore. After
entering "qed" for a solved proof, you can use ":addproof" to have it
automatically appended to your source file.


#### Conditional proofs

So far so good! But we said users can only redeem tokens if they have made
enough recommendations to other users, and that's something we can only know
at runtime. [Idris](http://en.wikipedia.org/wiki/Ivor_the_Engine#Idris_the_Dragon)
might be magic, but even Idris can't predict the future.

We want a redeem function with types History -> Redeem -> History, but unless
we want to return the original, unchanged history, it'd be impossible to
redeem a token if a user didn't have enough recommendations. We'll try
History -> Redeem -> Maybe History instead, and it'll look a little something
like:

```
redeemToken : History -> Redeem -> Maybe History
redeemToken (MkHist _ _ Z     _ _ _) _     = Nothing
redeemToken (MkHist u r (S o) e p v) token =
  Just $ MkHist u (S r) o e ?redeemPrf (Left token :: v)
```

Remmeber that weird looking offset value we carry around in the History type?
It's time to put it to use! If we didn't have an offset we'd only ever know
that we had a number of redeemed tokens less than or equal to the number of
earned tokens, and r <= e isn't enough information to prove r + 1 <= e.

The offset lets us rewrite everything as r + o <= e. If o is 0 (the natural
number Z) then the problem reduces to r <= e and can't be solved. But if o is
greater than 0 then we can always rewrite r + (o + 1) as (r + 1) + o. This
lets us increase the count for redeemed tokens and the size of our history
vector.


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

And if you want to see the silly example in its entirety, it's all conveniently
in a [gist](<gist>).


#### Sign me up!

Get started with this amazing new technology by installing the [Haskell
Platform](http://www.haskell.org/platform/) (if you don't have GHC and
cabal-install on your system already), and running the commands:

```console
cabal update
cabal install idris
```

Now you can work through the tutorial on the
[docs](http://www.idris-lang.org/documentation/) page to learn more!

