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
tags: Nimrod, GTK
---
```

Save the article as: ``2013-08-18-gtk-plus-i-love-gtk-and-here-is-why.rst``,
or something else, the filename doesn't really matter, *ipsum* does not care.

You then need to create some layouts and put them into the layouts folder.
You will need the following layouts:

* article.html -- Template for an article.
* default.html -- Template for the index.html page, this includes the article
  list.
* tag.html -- Template for the specific tag page, this will include a list of
  articles belonging to a certain tag.

Layouts are simply html templates,
*ipsum* will replace a couple of specific strings in the html templates when
it's generating your blog. The format of these strings is ${key}, and the
supported keys are:

* ``${body}`` -- In default.html this is the article list, in article.html
  this will be the actual article text.
* ``${title}`` -- Article title, article.html **only**.
* ``${date}`` -- Article date, article.html **only**.
* ``${prefix}`` -- The path to the root in article.html **only**.
* ``${tag}`` -- The tag name, tag.html **only**.

You will also need to create an ``ipsum.ini`` file, the file should contain
the following information:

```ini
title  = "Blog title here"
url    = "http://this.blog.me"
author = "Your Name"
```

The information from this config is also available in your templates, the key
names match the names in the config file.

Once you're done with the setup, simply execute ``ipsum`` and your blog should
be generated before you can even blink!

## License

MIT