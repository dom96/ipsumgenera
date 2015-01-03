# ipsum genera

*ipsum genera* is a static blog generator written in Nimrod. It's something
I hacked together in a couple of days so you're mostly on your own for now if
you wish to use it. Of course, I love the name *ipsum genera* so much that I
may just be willing to make this more user friendly.

## Quick manual

To set up *ipsum* you first need to install [nimrod's nimble package
manager](https://github.com/nimrod-code/nimble). Once you have that installed
you can run:

```
git clone https://github.com/dom96/ipsumgenera
cd ipsumgenera
nimble install
```

This will compile *ipsum* and copy it to your ``$nimbleDir/bin/`` directory. Add
this directory to your ``$PATH`` environment variable so you can run *ipsum*
anywhere.  In the future if you need to update your *ipsum* version you will
need to refresh that checkout and run ``nimble install`` again to overwrite your
current copy.

Now, go to the directory of your choice for storing your own website and
create the structure to hold your content:

```
cd ~/projects
mkdir -p super_website/articles
mkdir -p super_website/static
mkdir -p super_website/layouts
cd super_website
```

Put articles in the ``articles`` folder with metadata similar to jekyll's:
```
---
title: "GTK+: I love GTK and here is why."
date: 2013-08-18 23:03
tags: Nimrod, GTK
---
```

Save the article as: ``2013-08-18-gtk-plus-i-love-gtk-and-here-is-why.rst``, or
something else, the filename doesn't really matter, *ipsum* does not care as
long as they have an ``rst`` extension. All other extension files are ignored.

Put static files in the ``static`` folder. If the file ends in ``.rst`` it has
to have metadata like a normal article, but the generated html will keep the
relative path instead of getting a generated one from the date+title. If the
file doesn't end in ``.rst``, it will simply be copied to the output website
directoy.

You then need to create some layouts and put them into the layouts folder.
You will need the following layouts:

* article.html -- Template for an article.
* static.html -- Template for a static file.
* default.html -- Template for the index.html page, this includes the article
  list.
* tag.html -- Template for the specific tag page, this will include a list of
  articles belonging to a certain tag.

Layouts are simply html templates, *ipsum* will replace a couple of specific
strings in the html templates when it's generating your blog. The format of
these strings is ${key}, and the supported keys are:

* ``${body}`` -- In ``default.html`` this is the article list, in
  ``article.html`` this will be the actual article text.
* ``${title}`` -- Article title in ``article.html``, otherwise the blog title
  from ``ipsum.ini``.
* ``${date}`` or ``${pubDate}`` -- Article publication date in ``article.html``
  extracted from the metadata.  The date has to be in format **YYYY-MM-DD
  hh:mm**.
* ``${modDate}`` -- Article modification date in ``article.html`` extracted
  from the metadata, or if not available from the file's last modification
  timestamp.
* ``${prefix}`` -- The path to the root in ``article.html`` **only**.
* ``${tag}`` -- The tag name, ``tag.html`` **only**.

Where ``article.html`` is mentioned, the same applies for ``static.html``. You
will also need to create an ``ipsum.ini`` file, the file should contain the
following information:

```ini
title  = "Blog title here"
url    = "http://this.blog.me"
author = "Your Name"
```

The information from this config is also available in your templates, the key
names match the names in the config file. Additional options you can add to the
``ipsum.ini`` file:

* ``numRssEntries`` - Integer with the maximum number of generated entries in
  the rss feed. If you don't specify a value for this, the value ``10`` will be
  used by default.

Once you're done with the setup, simply execute ``ipsum`` and your blog should
be generated before you can even blink!

## Metadata reference

* ``title`` - Article title.
* ``date`` or ``pubDate`` - Date the article was written.
* ``modDate`` - Specifies a posterior date the article was updated. If you
  don't specify this tag, it will be filled in with the file's last
  modification timestamp.
* ``tags`` - Tags belonging to the article.
* ``draft`` - If ``true`` article will not be generated.

## License

[MIT license](LICENSE.md).
