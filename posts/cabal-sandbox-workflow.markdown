---
title: Haskell Development with Cabal Sandboxes
date: 2014-01-10
tags: code, haskell
metadescription: An intro guide to using cabal sandboxes as part of your haskell workflow
---

Cabal sandboxes were introduced in cabal 1.18, and they're designed to let you
build Haskell packages in isolated environments. Cabal sandboxes are largely
based on the
[cabal-dev](https://hackage.haskell.org/package/cabal-dev) tool, and similar in
spirit to
[hsenv](http://hackage.haskell.org/package/hsenv) (which has some
other advantages).<sup>[1](#footnote1)</sup>

#### Simplifying your workflow

The motivation for isolating environments is straightforward: if you're working
on more than one project at a time, the projects may have conflicting
dependencies, and managing all of them at the system level is a nightmare.

Throw in large libraries and web frameworks at different versions and you have a
recipe for dependency hell. Trying to resolve and accommodate every new build
error at the system level is enough to make anyone superstitious, performing
archaic rituals and beseeching the mighty build gods before daring to run their
next cabal command.

Even if you manage to make it work, it leaves your system environment in a state
that might not be easy to reproduce, making it harder to troubleshoot build
issues others might experience with your software. After having been through
this enough times on my own (and across enough languages), I finally realized
that sandboxes shouldn't be the exception during development: they should be the
default.<sup>[2](#footnote2)</sup>

#### Versions used here

Before we work through a quick example, here are the versions I'm using:

```
$ ghc --version
The Glorious Glasgow Haskell Compilation System, version 7.6.3
$ cabal --version
cabal-install version 1.18.0.1
using version 1.18.0 of the Cabal library
```

#### Example: building this blog

My blog is created with [Hakyll](http://jaspervdj.be/hakyll/), a Haskell library
with many dependencies. If you wanted to learn Hakyll and use my code as a
starting point, it's entirely possible (and likely) that something in the chain
of dependencies will conflict with Haskell libraries you have installed at the
system level.

Here's how you can build `chromaticleaves` in a sandbox to avoid these issues:

```
$ git clone git@github.com:ericrasmussen/chromaticleaves.git
$ cd chromaticleaves
$ cabal sandbox init
Writing a default package environment file to
/path/to/chromaticleaves/cabal.sandbox.config
Creating a new sandbox at /path/to/chromaticleaves/.cabal-sandbox
```

Now that we're in a sandbox, the next step is installing all the dependencies
from
[chromaticleaves.cabal](https://github.com/ericrasmussen/chromaticleaves/blob/master/chromaticleaves.cabal)
(it's a deceptively short list, but Hakyll will pull in many other
dependencies):

```
$ cabal install --only-dependencies
```

Hopefully everything will install fine, but you may still see some missing
system dependencies or other issues depending on your OS. The output from the
install command should provide details.

Once you've got that sorted out, you can install the `site` binary with:

```
$ cabal install
```

This will create the executable .cabal-sandbox/bin/site that you can use to
launch the site locally with "site preview", rebuild after changes with
"site rebuild", and anything else from Hakyll's
[The Basics](http://jaspervdj.be/hakyll/tutorials/02-basics.html) tutorial.

Lastly, you can even jump into a fully loaded GHCi session using:

```
$ cabal repl
```

Which will start GHCi with all of the top level functions from the
`chromaticleaves` main source file.

#### Path hackery

When you cabal install anything in your sandbox (including any executables from
the software you're developing), they're placed in
*your/sandbox/.cabal-sandbox/bin*. It's convenient to add this relative
path to your system's [$PATH
variable](http://en.wikipedia.org/wiki/PATH_%28variable%29):

```
.cabal-sandbox/bin
```

Preferably adding it before your user cabal bin and other bin
folders. Specifying it as a relative path means that when your current working
directory contains a sandbox, any binaries installed there take precedence.

However, note that this only works for executables installed with "cabal
install" in your sandbox. There's also a "cabal build" command that creates dist
files in meaningfully named subfolders. The command will work just fine, but
note that the simple relative path we used above won't pick up any binaries
installed that way.

If you followed along on the above blog building example, then going to the
chromaticleaves directory should automatically place the sandboxed `site` on
your path. You can verify with:

```
$ which site
.cabal-sandbox/bin/site
```

#### Ignorables

Initializing a cabal sandbox will add a hidden folder and a config file to your
current working directory. If you manage your project with version control, you
should add these to your ignore/boring files:

```
.cabal-sandbox/
cabal.sandbox.config
```

#### Further reading

There are many common commands and other usage patterns not covered here. The
best thorough introduction to using cabal sandboxes is [An Introduction to Cabal
sandboxes](http://coldwa.st/e/blog/2013-08-20-Cabal-sandbox.html).

It's a must-read if you plan on using them, and you should also keep the official
[Cabal User Guide](http://www.haskell.org/cabal/users-guide/installing-packages.html#developing-with-sandboxes)
handy as a reference.

<hr />

<sub><a id="footnote1">1.</a> hsenv only works on *nix systems but has the
advantage of fully sandboxing ghc, ghci, and cabal, instead of relying on their
system versions and only sandboxing build dependencies.</sub>

<sub><a id="footnote2">2.</a> Of course, there are other solutions to this
problem: jails, containers, VMs, buying a new laptop for each project, etc.
</sub>


