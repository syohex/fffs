find-file-from-selection
========================

Open a file by matching the current contents of the clipboard (mouse
selection) and locating the file, possibly by searching for it.

Demo
----

<a href="https://koldfront.dk/emacs/fffs/demo.html"><img width="454" height="393" src="https://raw.githubusercontent.com/asjo/fffs/master/demo.png" alt="asciinema demo" /></a>

Setup
-----

Put these lines in your `~/.emacs/init.el`:

```elisp
(add-to-list 'load-path "$PATHTOFFFS") ; fill in the path where you put the library
(require 'find-file-from-selection)
(define-key global-map (kbd "C-c C-f") 'find-file-from-selection) ; use the key you like
```

Usage
-----

 * Select text containing filename (and maybe line (and maybe column))
 * Press C-c C-f
 * Emacs opens the file

Motivation
----------

Often you see an error message in your terminal pointing you to a code
line with an error.

Opening the file in Emacs and jumping to the line can be non-trivial -
i.e. you perhaps select the file name in the output with the mouse, do
C-c C-f (find-file) in Emacs, and then paste the filename using the
middle mouse button in the mini buffer. Much of this is Fiddly stuff!

This is what this library tries to help with:

Simply select the text containing the filename with your mouse (can
often be done with a double- or triple click) and use your handy
shortcut to `find-file-from-selection` to have Emacs interpret the
selected text and find the file for you, jumping to the line- and
character, if included in the selected text.

The output doesn't always include the entire path to the file, which
is why the library goes hunting for the file. It looks for the file in
the current directory first, then recursively in the current
directory, and finally recursively in any directories you have put in
`find-file-from-selection-directories` (if you have specific
directories where source code lives, adding these could be an idea)..

Note that if the "filename" contains slashes, the library will try to
peel off one level at a time from the left, when looking recursively
(handling the output from e.g. git, where a path has an "a/" or a "b/"
prepended).

Author
------

Adam Sjøgren &lt;asjo@koldfront.dk&gt;

License
-------

Copyright (C) 2016, Adam Sjøgren. Released under the GPLv2.
