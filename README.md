# What is this?

reader2maildir downloads fresh items from your [Google Reader](http://www.google.com/reader) account,
and places them into a local Maildir.  Seen marks are propagated both
ways, so if you read an article locally, it will be marked as read
remotely, and vice versa.

So by using reader2maildir, you can read your Google Reader items in
[Gnus](http://www.gnus.org/), and the seen marks will be synchronized.

## Install

Put the `.rb`'s files in a directory somewhere.
   
## Getting Started

Create a file named `~/.reader2maildir` in your home directory, which
is a [YAML](http://www.yaml.org/) configuration file.

  username: _your username_@gmail.com
  password: _your password_
  maildir: _full path to the maildir you want to use_

Each time you run `reader2maildir.rb`, fresh items will be downloaded
from Google Reader and placed in subdirectories under `maildir`
corresponding to the feed.  Articles which are locally marked as read
will be marked as read remotely, and vice versa.
