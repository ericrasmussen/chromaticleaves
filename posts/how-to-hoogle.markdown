---
title: Adventures in Hoogling
date: 2014-03-31
tags: code, haskell
metadescription: Getting started with hoogle and using it with cabal sandboxes
---

[Hoogle](http://www.haskell.org/hoogle/) is the de facto tool for searching
types and documentation in Haskell libraries, and it's simple to install and use
at the command-line or in the browser. At least, until you decide you'd like a
straightforward way to create your own Hoogle database for all libraries
installed in a cabal sandbox. Which, incidentally, was the original motivation
for this post.

Things didn't go quite as smoothly as expected.

But before we get to that...

#### How to Hoogle: the easy way

Hoogle is easy to `cabal install` and get started with locally. For many use
cases, all you need is to install it and populate it with data using either:

```console
# creates databases for many common libs
hoogle data
```

Or:

```console
# creates databases for a whole lot of libs
hoogle data all
```

If you're using sandboxes, you may have to specify the location of Hoogle with
`.cabal-sandbox/bin/hoogle data` (even though I had that instance of Hoogle
higher up on my search path, I ran into a quirk in my environment where it
couldn't find the cabal dirs it needed if I didn't specify the relative path).

From there you can start searching at the command-line:

```console
$ hoogle "(a -> b) -> [a] -> [b]"
Prelude map :: (a -> b) -> [a] -> [b]
```

Or you can run `hoogle server -p 1234` to serve the web version on localhost
at port 1234 (or port of your choice).


#### How to Hoogle: the GHCi way

GHCi is more than just a Haskell interpreter: you can also use it to issue
shell commands. If you haven't done this before, try it out! You can prefix
shell commands with `:!`. For instance, `:!pwd` will print the current working
directory in GHCi.

This means you can also call Hoogle from within GHCi, assuming it's on your
path:

```console
Prelude> :! hoogle "[a] -> Int"
Prelude length :: [a] -> Int
```

This works, but it's a little clunky to have to quote the search term. There's a
[Hoogle entry](http://www.haskell.org/haskellwiki/Hoogle) on the HaskellWiki
with a tip for getting around this. You can add this to your `.ghci` file
(in your cabal sandbox folder, project folder, or as described
[here](http://www.haskell.org/ghc/docs/7.4.2/html/users_guide/ghci-dot-files.html)):

```console
# .ghci
:def hoogle \x -> return $ ":!hoogle \""        ++ x ++ "\""
:def doc    \x -> return $ ":!hoogle --info \"" ++ x ++ "\""
```

Now you can call them handily within GHCi:

```console
*Main> :hoogle head
Prelude head :: [a] -> a
Data.List head :: [a] -> a
...
*Main> :doc head
Prelude head :: [a] -> a

Extract the first element of a list, which must be non-empty.

From package base
head :: [a] -> a
```

Especially when you're first learning a library, it can also be helpful to
limit search results to that library. For instance, if you want to find all
of the Hakyll functions that make use of `Compiler`, use `+hakyll` to search
only that module:

```
Prelude> :hoogle +hakyll Compiler
Hakyll.Core.Compiler data Compiler a
Hakyll.Core.Compiler module Hakyll.Core.Compiler
...
```

#### How to Hoogle: your own way

The next step in my journey for making the most of Hoogle was finding a way to
search my current project while working on it. The high level process for
creating a Hoogle database is to use `haddock` (commonly via `cabal haddock`) to
generate a text file suitable for consumption via Hoogle, convert the text file
to a `.hoo` Hoogle database, and combine it with an existing Hoogle database.

Let's break it down. First, cabal has a haddock command that is very convenient
to use when working with sandboxes. The `--hoogle` flag will generate a text
file database, and `--all` says to generate one for everything in the package in
the current working directory (you could also specify any of `--executables`,
`--tests`, of `--benchmarks`). If you're writing a library, you don't need to
specify `--all`, but it's useful when you want to be able to search everything
in your current project:

```console
cabal haddock --hoogle --all
```

Now we can use Hoogle's `convert` command to create a `.hoo` file from the text
database. The text file should be somewhere in the current working directory
under dist/doc/html:

```console
hoogle convert dist/doc/html/path/to/your/package/docs.txt
```

Lastly you can combine it with the `default.hoo` database (typically somewhere
in your global, user, or sandbox `cabal/share` folder):

```console
hoogle combine default.hoo dist/doc/html/path/to/your/package/docs.hoo
```

### How to Hoogle: the hard way

My original goal was making it easy to generate a database with all the
packages in a cabal sandbox. It turned out to be challenging for a few reasons,
one of which is that cabal installing packages (sandbox or no) doesn't create
the `.txt` or `.hoo` files needed by Hoogle. Some quick research shows that
adding this type of functionality isn't a new
[issue](https://github.com/haskell/cabal/issues/395).

This is by no means a trivial addition to `cabal`, but it's arguably the
cleanest solution to the problem.

However, if you want a quick hack in the meantime, the basic idea is making use
of:

#. `ghc-pkg` to get a list of sandboxed packages
#. `cabal get` to fetch each package's source code
#. `cabal haddock` to generate `.txt` databases for each
#. `hoogle convert` to create the `.hoo` databases
#. `hoogle combine` to merge the databases into a single `default.hoo`

This process isn't perfect, but it'd look something like this:

```console
# get an easy to parse list of packages pinned at their installed versions
ghc-pkg list --package-db=".cabal-sandbox/<architecture>-ghc-<version>-packages.conf.d/" --simple-output
# then for each package:
cabal get <package> -d <destination directory>
cabal haddock --hoogle --haddock-options='<package>/Setup.hs'
cabal convert <package>/dist/doc/html/<package>.txt
cabal combine path/to/default.hoo <package>/dist/doc/html/<package>.hoo
```

This approach is problematic because not all installed packages are libraries
(in which case `cabal haddock` will generate errors and not exit cleanly), the
location and name of the setup file may vary, and having to `cabal get` a lot of
packages can be an expensive and time consuming operation.

Overall I've found it much easier to start with `hoogle data all` and then add
my own package, rather than try to automate database creation for sandboxed
libraries. You get greater search capabilities (sometimes with too many results,
but it's easy to limit the search by module), and it doesn't stop you from
building your own databases as needed.


#### References

Some links I found indispensable in learning the various ways one can Hoogle:

* [Hoogle manual](https://github.com/ndmitchell/hoogle/blob/master/README.md)
* [Neil Mitchell's post on database generation](http://neilmitchell.blogspot.com/2008/08/hoogle-database-generation.html)
* [Hoogle wiki entry](http://www.haskell.org/haskellwiki/Hoogle)
* [Online Hoogle search](http://www.haskell.org/hoogle/)

