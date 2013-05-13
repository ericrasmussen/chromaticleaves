---
title: Software as a Process
date: 2013-04-12
tags: code, soapbox
metadescription: The benefits of adding context to code documentation by viewing software as a process.
---

There is a fundamental distinction between viewing tasks in
terms of their end results (the product), and viewing them in terms of their
development (the process). It's important to be conscious of both, but I've
found that the product over process mentality is far more common than the
reverse, and this way of thinking can have a negative impact on projects.

One of the issues with focusing on the end product is that, inevitably, the
needs of your users will change, or the environment around the product will
change. If you've written the code and documented the code to account only for
this ideal product, frozen in time, then as soon as the product loses value,
your code and documentation lose value too.

If we accept for a moment that this is truly inevitable, then the psychological
benefit to process over product is that our code and supporting docs will be
aware of its doomed future, and hypothetically we can better plan for it. As
programmers, our natural inclination is usually to throw more code at problems,
and it's definitely worth exploring best practices for writing extensible
code. A good starting point is Chris McDonough's talk on [API Design for Library
Authors](http://pyvideo.org/video/1705/api-design-for-library-authors).

But even then, the most well-intentioned and extensible code will eventually
succumb to time. One way we can try to account for this is to add that level of
awareness to our code documentation. If we assume nothing in our code is future
proof no matter how well planned, then one role of the documentation should be
helping future readers understand the design process. We want to give them
insight into how we arrived at our conclusions.

For fun, let's pretend you're working for the venerable Gibberton Industries,
and you're tasked with parsing 3rd party CSV files and loading them into a
database. Everyone knows the files you get will never have more than 100-200
rows, which is good because the only CSV library available to you, NiftyCSV,
loads entire files into memory in a very inefficient way.

Fast forward five years. You've moved on, and now I've been brought in to find
out why your scripts are failing and no data is making its way to the database.
In this new time and context, it's completely unthinkable that anyone would
use NiftyCSV for anything. It's a barely remembered, unmaintained library, and
these days there are plenty of robust options to choose from. I see that the
obvious issue is you're using NiftyCSV to load files into memory when the files
are hundreds of thousands of rows a piece, and no one in the business remembers
a time when they were any smaller.

When I look to your code for answers, I find this comment:

*Use NiftyCSV to parse the files and load them in our database.*

Remember that now I'm in the future, and no one writes code the way you wrote it
anymore. Reading that comment, I'm wondering if you were mad, incompetent, or,
worse, brilliant. Maybe you wrote the solution the way you did for a subtle and
mysterious reason that I can't see, and when I try to address the immediate
memory issue, I may inadvertently break something else.

The comment I should see is:

*Use NiftyCSV to parse the files and load them in our database. NiftyCSV
is the only stable CSV library available, and we only expect CSV files
to have 100-200 rows each.*

The amount of work required to update the code may be the same in both cases,
but in the latter scenario I have the confidence I need to make changes. When
your documentation includes this level of awareness and commentary, it lets new
developers (or even future versions of you) step into the context in which it
was written to better understand how it can be changed.

The required shift in focus from product to process may seem subtle, but it has
profound implications for how you think about development and how you document
and evolve your codebase over time. It takes very little time to add a sentence
or two per module (or other unit of code) to make future maintainers and
readers a part of the process.
