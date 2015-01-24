---
title: Nix in Two Days
date: 2015-01-25
tags: code, nix, ops
metadescription: Add the Nix package manager to your workflow in two days
---

This article begins with a deceptively simple premise: if you write software,
you should learn to use software packages. It's deceptive bceause blog posts
that throw around unqualified terms like "simple" should not be trusted, and
also because we're going to move beyond traditional notions of "software
package".


#### Package management in a nutshell

A famous saying in software development (that I just made up) is:

> There are two hard problems in software development: packaging, and deployment.

If you write code, sooner or later you'll want to leverage
someone else's code, and that's where packaging comes into play. Not long after
that you may want to run your code somewhere other than your works-for-me
machine, and then you're faced with the non-trivial task of deployment.

There are at least 108,000,000 known methods<sup>[1](#footnote1)</sup> of
software deployment, but it turns out that all of them benefit from package
management. Whether you use virtual machines, containers, or configuration
management tools like Muppet and Swedish Chef, your deployment strategy will be
greatly simplified if you can make use of software that's already been reliably
packaged.

The next question then is not whether to use package management, but what package
manager to use? A survey taken today shows at least 9,080,000<sup>[2](#footnote2)</sup>
different package managers being used today, and I'm going to introduce you to
a relatively new one called Nix.

#### My initial reaction to Nix


![](/images/xkcd_standards.png "Standards (xkcd.com)")

<a href="http://xkcd.com/927/">Standards (xkcd.com)</a>


#### Why do we need a new package manager?

Because it *is* different! The motivation for Nix, and explanations of its
basic features and concepts, have already been
[well](http://nixos.org/nix/)
[covered](https://www.domenkozar.com/2014/03/11/why-puppet-chef-ansible-arent-good-enough-and-we-can-do-better/)
[elsewhere](http://lethalman.blogspot.com/2014/07/nix-pill-1-why-you-should-give-it-try.html).

I'm going to hope that if you've made it this far, you already have some
interest in it. I'd like to show you how you can incorporate the Nix package
manager into your workflow in two days with minimal disruption and time.


#### Day 1: Installation

One of Nix's defining features is the packages it builds will not depend on
global install directories (`/usr`, `/lib`, etc), and the packages will be placed
in the `/nix/store`. This makes it easy to use alongside existing package managers, because it will not influence
or depend on your globally installed packages.<sup>[3](#footnote3)</sup>

For Linux or Mac OS X users, the official installation instructions are
available on [http://nixos.org/nix/](http://nixos.org/nix/). Here's the short
version as of January 2015:

```console
$ curl https://nixos.org/nix/install | sh
$ source ~/.nix-profile/etc/profile.d/nix.sh
```

The first step will set up the `/nix/store` and install utilities like
`nix-env` that you will use to manage Nix. If you're worried about relying on
`curl` for the install you can read the
[installation chapter](http://nixos.org/nix/manual/#chap-installation) of the
manual for further options.

The second step will source a shell script that will setup your `$NIX_PATH`
and modify your user's `$PATH` so it can find utilities installed by Nix.

Now you can find packages by using `nix-env -q` and grepping for whatever you're
looking for. Here's a quick example that will run a query (flag `q`) for
packages available (flag `a`) on your platform, including the package's
attribute path (flag `P`):

```console
nix-env -qaP | grep -i cowsay
nixpkgs.cowsay                    cowsay-3.03
```

Now you can either install by name:

```console
nix-env -i cowsay-3.03
```

Or by attribute path (note that we have to add the flag `A` to indicate we're
installing by attribute):

```console
nix-env -iA nixpkgs.cowsay
```

Congratulations! You've installed your first package with Nix. If you aren't
sure what to do next, try out ```nix-env -i nix-repl``` and you can practice
interacting with Nix in a shell. Examples and getting started instructions
for `nix-repl` are available [here](https://github.com/edolstra/nix-repl).

You're now free to install packages without breaking system packages, without
obscure failures due to globals, and without dependency hell.<sup>[3](#footnote4)</sup>


#### Day 2: myEnvFun

There are a lot of Nix features that have improved my development workflow, and
it's very had to pick just one to cover here. However, at the beginning of this
post I promised we'd expand on the common notion of what it means to be a
package, and `myEnvFun` does just that.

Note: the "Fun" in `myEnvFun` is for functional. The Nix project makes no claims
or guarantees of enjoyment derived from using it.

One of the (many) complications in software development is identifying and
isolating all of the tools you need to work on a particular project. Sometimes
the tools might not require a particular version and may make sense to have
globally, like `git`, or your favorite text editor. Other times you might have
projects with conflicting dependencies, like two or more haskell projects using
two or more versions of the compiler `ghc`.

What we'd like to do is define different environments containing those tools so
we can easily switch between them. When you run the `nix-env` utility it will
check for the existence of a file `~/.nixpkgs/config.nix`, which may contain
package overrides you've specified for your user. If that directory or the
`config.nix` file do not exist, you can create them.

Here's an annotated example showing how we can create development environments
for two different versions of `ghc`:

```perl
# ~/.nixpkgs/config.nix
{
  # ~/.nixpkgs/config.nix lets us override the Nix package set
  # using packageOverrides. In this case we extend it by adding
  # new packages using myEnvFun.
  packageOverrides = pkgs : with pkgs; {
        ghc76 = pkgs.myEnvFun {
	  name = "ghc76";
	  buildInputs = [ ghc.ghc763 ];
	};
        ghc78 = pkgs.myEnvFun {
	  name = "ghc78";
	  buildInputs = [ ghc.ghc783 ];
	};

   };
}
```

Here's how we can install and use the first one:

```console
# to be filled in
```

What we've done here is defined a new package (leveraging the Nix built-in
`myEnvFun`) that puts a binary on your path for loading a shell environment with
a particular set of packages ready and available.

There are a lot of important ideas we could cover here (now to read Nix
expressions, how to find documentation for built-ins, and many more), but we'll
stop for now to keep this a one day learning experience. You can now experiment
with your own environments using that format, and adding your own `buildInputs`
to them (note that in Nix, lists are space-delimited, so remember to avoid
commas in lists like `buildInputs = [ one two three];`).


#### How to get your money back

Not literally of course. But if it's just not working out for you, you can
always uninstall Nix:

```console
$ rm -rf /nix
$ rm -rf ~/nix-profile/
```

Since packages are only able to create files in the `/nix/store`, you don't need
to worry about them having littered files in your global directories.


#### Learning more

There's a lot more to Nix. There's Nix the language (in order to write your own
packages you should learn how to write Nix expressions), NixOS the Linux
distribution (which lets you write NixOS modules, providing a config
management-like layer), and a whole lot more.

Here are some resources for getting started:

* [Nix Manual](http://nixos.org/nix/manual/)
* [Nix Papers](http://nixos.org/docs/papers.html)
* [Nix Wiki](https://nixos.org/wiki/Main_Page)
* [Nix pills](http://lethalman.blogspot.com/2014/07/nix-pill-1-why-you-should-give-it-try.html)
* [NixOS Tips (Twitter)](https://twitter.com/NixOsTips)


<hr />

<sub><a id="footnote1">1.</a>Wait I think I meant google search results for "software deployment"</sub>

<sub><a id="footnote2">2.</a>Yes I'm still using google search results</sub>

<sub><a id="footnote3">3.</a>Note that this only applies to where software is installed. If you install
`cowsay` via `apt-get` and `nix-env` then your user's `$PATH` will determine which one is used.</sub>

<sub><a id="footnote4">4.</a>If you use the unstable Nix channel, you will still encounter build failures
for other reasons (for instance, some compiler gets a version bump and some other package that depended on
a bug or removed feature can no longer build against it)</sub>