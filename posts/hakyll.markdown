---
title: Blogging with Hakyll
date: 2013-04-11
tags: code, haskell, hakyll
metadescription: An overview of why Hakyll is an awesome way to blog for haskellers and hackers.
---

The biggest barrier to actually maintaining a blog isn't having ideas, or even
writing them down, but having to manage content. Typically content hosted on a
web site somewhere, protected by a password, navigable through a user interface
that requires clicking... oh, lots of clicking. It's usually something along the
lines of:

```
1. Go to the admin page for my blog or CMS
2. Login with a password
3. Click around to create a new post or find a saved draft
4. Try to make the rich text editor do what I want
5. Give up and use html
6. Save and publish the changes
```

It's all a lot of work, and I am finding it an increasingly unsustainable
workflow when I spend much of my day in emacs or at the command line. For
comparison, here's my workflow for open source software contributions:

```
1. Write something in a text editor
2. Run some commands in a terminal
```

With hakyll, now I get:

```
1. Write something in a text editor
2. Run some commands in a terminal
```

There are no shortage of static blog generators now that they're in style,
but hakyll stood out for me because it has a clean DSL-like feel, I'm at home
with haskell, and pandoc is amazing. I plan to write blog posts primarily in
markdown, but I also may use ReST or LaTeX, and hakyll's default
`pandocCompiler` can handle them all (and a number of others; see the
[pandoc website](http://johnmacfarlane.net/pandoc/) for more).

My other goal (not specific to hakyll) is making this a truly open source blog,
in the sense that you are welcome to clone it and fork it. I'd prefer you don't
steal all my posts of course, but you are completely free to use my site.hs file
however you wish.
