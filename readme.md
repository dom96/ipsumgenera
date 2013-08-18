# ipsum genera

*ipsum genera* is a static blog generator written in Nimrod. It's something
I hacked together in a couple of days so you're mostly on your own for now if
you wish to use it. Of course, I love the name *ipsum genera* so much that I
may just be willing to make this more user friendly.

## Quick manual

```
git clone https://github.com/dom96/ipsumgenera
cd ipsumgenera
babel install
mkdir articles
mkdir layouts
```

Put articles in the 'articles' folder with metadata similar to jekyll's:
```
---
title: "GTK+: I love GTK and here is why."
date: 2013-08-18 23:03
tags: [Nimrod, GTK]
---
```

Save the article as: ``2013-08-18-gtk-plus-i-love-gtk-and-here-is-why.rst``,
or something else, the filename doesn't really matter, *ipsum* does not care.

You then need to create some layouts and put them into the layouts folder.
Two for now: article.html and default.html. This is simply an html template,
*ipsum* will replace a couple of specific strings in the html template when
it's generating your blog. The format of these strings is ${key}, and the
supported keys are:

* ``${body}`` -- In default.html this is the article list, in article.html
  this will be the actual article text.
* ``${title}`` -- Article title, article.html **only**.
* ``${date}`` -- Article date, article.html **only**.
* ``${prefix}`` -- The path to the root in article.html **only**.

Once you're done with the setup, simply execute ``ipsum``.

## License

MIT