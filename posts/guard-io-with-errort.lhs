---
title: Playing Catch: Handling IO Exceptions with ErrorT
date: 2013-07-20
tags: code, haskell
metadescription: Examine ways to safely convert Haskell IO exceptions to native ErrorT exceptions
---

Before we get started, I'm going to assume you have some basic familiarity with
Haskell's monads, monad transformers, and exceptions. If not, no time's better
than the present to [Learn You a Haskell](http://learnyouahaskell.com/).

This blog post is written in literate Haskell, so you can copy and paste the
contents into a .lhs file and load it in GHCi to try out the examples. Speaking
of which, let's declare the language pragmas and imports we'll need for the
examples to follow:

> {-# LANGUAGE FlexibleContexts, GeneralizedNewtypeDeriving, MultiParamTypeClasses, TypeFamilies #-}
>
> import Prelude hiding               (catch)
>
> import Control.Applicative
>
> import System.IO.Error              (tryIOError)
>
> import Control.Exception            (IOException)
>
> import Control.Monad                (liftM)
>
> import Control.Monad.Base
>
> import Control.Monad.Trans.Control
>
> import Control.Exception.Lifted     (catch)
>
> import Control.Monad.Error          ( ErrorT
>                                     , Monad
>                                     , MonadIO
>                                     , MonadError
>                                     , liftIO
>                                     , runErrorT
>                                     , throwError
>                                     )
>


<h3>Motivation</h3>

There are many different ways to represent the notion of failure in a program.
One nice approach in Haskell is building a monad transformer stack and including
ErrorT to add error handling. However, ErrorT's notion of failure conflicts with
the one used by many IO functions. If you've always wished you could
use a safer version of liftIO that automatically caught IOExceptions and
converted them to errors in ErrorT, read on!

But first...

<h3>What's in an exception?</h3>

When it comes to exceptions in programming, their usage and meaning can vary
considerably by language, community, and problem domain. However, if we take a
step back and consider the meaning of "exception", it refers to cases that are
uncommon, or even *exceptional*. Viewed in this context, it's not surprising
that in many languages, these exceptional cases can hijack the flow of our
program or cause an abrupt and abnormal exit.

Of course, in practice, exceptions aren't always quite so exceptional. Sometimes
they're quite mundane, predictable, and easy to deal with in many other
ways. Let's consider a basic divide function that takes two arguments of type
Double, divides them, and returns the result:

> divide :: Double -> Double -> Double
> divide x 0 = error "Cannot divide by zero! Don't even try!"
> divide x y = x / y

This function makes a very important tradeoff: it chooses brevity and optimism
at the cost of an error case that could cause our program to terminate. Although
we can't tell from the type signature alone, this version of divide uses the
error function (its type is String -> a), which will result in
[bottom](http://www.haskell.org/haskellwiki/Bottom).

The unfortunate consequence is we've created a partial function that will fail
for some inputs, yet we're able to type check just fine. As long as no one ever
attempts to divide by zero, it even works as expected!

But if, like me, you're partial to total functions, you'll probably want to use
an algebraic type like Maybe instead:

> divide' :: Double -> Double -> Maybe Double
> divide' x 0 = Nothing
> divide' x y = Just $ x / y

Our definition is still concise, and our function is now defined over all
possible inputs of type Double without requiring error. A possible downside is
we've now deferred some of the burden to the caller, forcing them to
consider both the Nothing and Just cases.

This works, and Maybe is a perfectly good result type for handling partial
functions. Sometimes, though, we might want to tell people *why* they didn't get
back a return value, and in those cases it's nice to be able to pass along a
message describing the failure:

> divide'' :: Double -> Double -> Either String Double
> divide'' x 0 = Left  "You should really know better than to divide by 0"
> divide'' x y = Right $ x / y

Like the Maybe example, the caller still needs to pattern match and consider two
cases, but this time the error case (Left) contains details about the failure.

It's possible to keep building on this idea by creating even richer data
structures to handle different notions of failure. Next we'll take a look at how
we can handle these error cases using ErrorT in a monad transformer stack.


<h3>One thousand and one monad derivations</h3>

We're going to build a relatively simple monad stack using ErrorT and IO. Here's
what our app stack looks like:

> newtype MyApp a = MyApp {
>   getApp :: ErrorT String IO a
>   } deriving (Functor, Applicative, Monad, MonadIO, MonadError String, MonadBase IO)
>


We've wrapped it in a newtype to encapsulate it, which is a good practice if
there's any chance you might ever modify it later (for instance, adding StateT
or ReaderT without having to necessarily change all the type signatures that use
MyApp). We're also using generalized newtype deriving to automatically create
instances of MyApp for several monad typeclasses we'll need.

If you need some inspiration for why and how to use monad transformers, there's
a nice [chapter](http://book.realworldhaskell.org/read/monad-transformers.html)
on them in Real World Haskell.

We'll also want a convenient way to evaluate computations in the context of our
monad and produce a result:

> runApp :: MyApp a -> IO (Either String a)
> runApp = runErrorT . getApp

Let's go back to the version of our divide function that used a Maybe
result. We'll redefine it here with a more explicit name:

> maybeDivide :: Double -> Double -> Maybe Double
> maybeDivide x 0 = Nothing
> maybeDivide x y = Just $ x / y

The notion of failure here (Nothing) is different than the one we get with
ErrorT in MyApp, so how can we bridge the two?

> tryDivision :: Double -> Double -> MyApp Double
> tryDivision n m = case maybeDivide n m of
>   Just d  -> return d
>   Nothing -> throwError $ "unable to divide " ++ show n ++ " and " ++ show m

To produce a value of MyApp Double, we can either return a Double to the
underlying MyApp monad (the Just case above) or use throwError with a string
(the Nothing case).

Now we can use tryDivision within a runApp block:

> appDivision :: Double -> Double -> IO (Either String Double)
> appDivision n m = runApp $ do
>   res   <- tryDivision n m
>   liftIO $ putStrLn " > successful division!"
>   return res

If the division fails, then our "successful division!" message will never be
printed. This is the same behavior we'd expect
from a function that throws an error in an imperative language, but in our case
we haven't altered the flow of our program, and our return type is still
referentially transparent.

Let's put it to the test:

> runDivision n m = do
>   result <- appDivision n m
>   case result of
>     -- adding some flourish to make the output pretty
>     Left  err -> putStrLn $ " > " ++ err
>     Right r   -> putStrLn $ " > " ++ "Received result: " ++ show r
>
> testDivision = do
>   putStrLn "Trying 42 / 0:"
>   runDivision 42 0
>   putStrLn "Trying 42 / 8:"
>   runDivision 42 8

If you try testDivision in GHCi you'll see:

```console
*Main> testDivision
Trying 42 / 0:
 > unable to divide 42.0 and 0.0
Trying 42 / 8:
 > successful division!
 > Received result: 5.25
```

So far so good. But programmers never get off this easy, even in
contrived examples like this one. New requirement time: now we want the app to
read a welcome message from a file and display it to the user at startup. If you
notice this sounds contrived (it is) or insane (it is), you haven't done enough
consulting.

Here's our naive approach:

> sillyExample = do
>   result <- runApp $ do
>     contents <- liftIO $ readFile "welcome_message"
>     liftIO $ putStrLn contents
>     divided <- tryDivision 42 8
>     liftIO $ putStrLn ("I divided 42 and 8 and got: " ++ show divided)
>
>   case result of
>     Left  err -> putStrLn ("Caught error: " ++ err)
>     Right _   -> putStrLn "No errors!"

Running this function (assuming you don't have a file named "welcome_message" in
the same folder as the program) will cause the program to terminate with the
message:

```console
*** Exception: welcome_message: openFile: does not exist (No such file or directory)
```

The competing notions of failure here are problematic; if we needed to perform
logging or cleanup tasks before exiting, the IO exception would bypass them,
disrupting the flow of our program and possibly making it more difficult to
reason about.

<h3>The road to safety</h3>

What are some ways to handle this? One obvious solution is writing a function of
FilePath -> MyApp String that will either convert an IOException to an error in
ErrorT, or return the contents to our underlying monad stack. Using tryIOError
from System.IO.Error makes this easy:

> guardedRead :: FilePath -> MyApp String
> guardedRead fp = do
>   contents <- liftIO $ tryIOError (readFile fp)
>   case contents of
>     Left  e -> throwError (show e)
>     Right r -> return r

Now we can replace our original call to readFile with guardedRead:

> sillyExample' = do
>   result <- runApp $ do
>     contents <- guardedRead "welcome_message"
>     liftIO $ putStrLn contents
>     divided <- tryDivision 42 8
>     liftIO $ putStrLn ("I divided 42 and 8 and got: " ++ show divided)
>
>   case result of
>     Left  err -> putStrLn ("Caught error: " ++ err)
>     Right _   -> putStrLn "No errors!"

This time we retain control of the program flow and get the error at the end
with our "Caught error" message. If we had to run additional cleanup tasks
we could safely run them at that point, without having lost any information
regarding the IO exception.

We've accomplished what we set out to do for this particular example, but can we
generalize this to any IO action? Sure!

> guardedAction :: (MonadIO m, MonadError String m) => IO a -> m a
> guardedAction action = do
>  result <- liftIO $ tryIOError action
>  case result of
>    Left  e -> throwError (show e)
>    Right r -> return r

Now we can use guardedAction (readFile "welcome_message") in
place of guardedRead, with the advantages that we can use guardedAction with
any IO action that may throw an IOException.

This approach is valid for our use case, but it seems redundant to inspect an IO
(Either IOError a) result only to convert it to another context that uses Either
for a similar purpose.

When I first wrote a version of guardedAction, my "there must be a pattern for
that" sense kicked in and compelled me to ask on
[haskell-cafe](http://www.haskell.org/mailman/listinfo/haskell-cafe) if this
functionality existed or if there were other approaches to the problem. The
current pattern for handling exceptions in monad stacks is to use the catch
function from Control.Exception.Lifted.

This will require us to create an instance of MonadBaseControl IO for our app:

> instance MonadBaseControl IO MyApp where
>    newtype StM MyApp a = StApp { unStApp :: StM (ErrorT String IO) a }
>
>    liftBaseWith f = MyApp . liftBaseWith $ \r -> f $ liftM StApp . r . getApp
>
>    restoreM       = MyApp . restoreM . unStApp


The above code may be understandably scary, but much of it exists to handle
wrapping and unwrapping the newtypes. The gist of it is the MonadBaseControl
typeclass provides a way to run a computation in the base monad of a monad stack
but still return the value back to the original stack. There is a history behind
how this pattern emerged and has been implemented in the past, so I recommend
reading Michael Snoyman's
[overview](http://www.yesodweb.com/blog/2011/08/monad-control).


The important point for us is we now can use the Control.Exception.Lifted catch
function to easily handle IOExceptions by converting them to Strings and
applying throwError:

> guardIO :: (MonadBaseControl IO m, MonadIO m, MonadError String m) => IO a -> m a
> guardIO action =
>   liftIO action `catch` \e -> throwError $ show (e :: IOException)

The catch function (m a -> (e -> m a) -> m a) is very useful for dealing with
exceptions in monadic contexts.

Our new guardIO function can now act as a drop-in replacement for liftIO to
handle IO exceptions as ErrorT errors:

> sillyExample'' = do
>   result <- runApp $ do
>     contents <- guardIO $ readFile "welcome_message"
>     liftIO $ putStrLn contents
>     divided <- tryDivision 42 8
>     liftIO $ putStrLn ("I divided 42 and 8 and got: " ++ show divided)
>
>   case result of
>     Left  err -> putStrLn ("Caught error: " ++ err)
>     Right _   -> putStrLn "No errors!"

Try running sillyExample'' in GHCi to confirm the division statements never get
printed, and the IO exception is caught as part of the Left case in the result.

At this point we're in good shape, but I want to add that if you are using an
instance of MonadError with a Left case other than String, we can even
generalize this further to:

> generalGuardIO :: (MonadBaseControl IO m, MonadIO m, MonadError e m)
>                => (IOException -> e) -> IO a -> m a
> generalGuardIO fromExc action =
>   liftIO action `catch` \e -> throwError $ fromExc e

This requires us to supply an additional function for converting the exception
to whatever error type we use with MonadError, but it covers a much wider
range of use cases. If we were to use this latter definition, our first attempt
at guardIO would become:

> guardIO' :: (MonadBaseControl IO m, MonadIO m, MonadError String m) => IO a -> m a
> guardIO' = generalGuardIO show


<h3>Updates: 2013-08-01</h3>

Based on feedback from the community, I'd like to add a couple of caveats and
clarifications.

First, this approach works best for command line utilities and small
standalone programs that need basic IO capabilities without requiring a lot of
complicated extra handling specific to IO exceptions. The catch function
in Control.Exception.Lifted is well-suited to this purpose.

On the other hand, this approach won't handle automatic catching of asynchronous
exceptions. If you're writing async code or using libraries that can throw
async exceptions, handling them requires different techniques. A good starting
point for learning more is Michael Snoyman's
[tutorial](https://www.fpcomplete.com/user/snoyberg/general-haskell/exceptions/catching-all-exceptions)
on FP Complete.

Additionally, [John W.](http://newartisans.com/) pointed out that some monads
may not be able to provide an instance of MonadBaseControl IO, such as those in
the popular conduit library.

