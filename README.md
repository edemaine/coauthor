# Coauthor #

**Coauthor** is a tool for group collaboration, discussion, keeping track of
notes/results of meetings, etc.  Its primary goal is to ease multiauthor
collaboration on unsolved problems in theoretical computer science, so
e.g. you'll find LaTeX math support; hopefully it will have applications
in other fields too.

## Features So Far ##

* Live updates/redraw of everything, thanks to Meteor.  No more hitting
  "reload".  If you're looking at a problem and someone posts/edits something,
  you see it as quickly as they see their preview (roughly 1-second delay).

* Etherpad style (OT) real-time editing of messages, if people feel like
  editing together (useful if e.g. working on a tex file together...).
  The "stop editing" is maybe a little weird but not sure of a beter way.
  When editing, you see near-instant updates from the other side(s).
  And I can still keep track of authorship!  (more or less)
  Also you get live previews with ~1-second delay, after the data has
  round-tripped with the server.  (1 second delay is to reduce the crazy
  number of "old versions" that will get saved -- server only pushes after
  document has not changed for 1 second.)

* Three formats for rendering:
  * [Github-style Markdown](https://guides.github.com/features/mastering-markdown/)
    (default)
  * HTML (sanitized)
  * LaTeX (very limited)
  All formats support LaTeX math (via `$...$` or `$$...$$`) via
  [KaTeX](https://khan.github.io/KaTeX/).  Easy to add additional formats.

* [Ace editor](https://ace.c9.io/) supports "regular" keybindings as well as
  Vim and (limited) Emacs style.  (If you've ever needed rectangular selection
  for e.g. ASCII art, that's built-in to this editor.)

* Organization by **groups** (intended to correspond to groups of people who
  meet).  Users can have permission to see and/or post within each
  group, or at a global level (mainly intended for admins).
  Admins can edit the permissions of other users via the "Users" button.

* **Sorting** of threads within a group by title, creator, creation date,
  last update, number of posts, or whether subscribed (by clicking on the
  corresponding column, once for default sort order and again for
  opposite sort order).  Intelligent handling of numbers while sorting,
  e.g. "9." comes before "10.".

* "Live Feed" to watch messages as they get changed/posted.  Useful for
  projecting the latest activity onto a big screen while a group is gathered
  and some are maybe editing.

* "Catchup on Recent Posts" to see all messages since a particular date/time
  (including relative specifications like "1 week" or "12 hours").
  Useful for progress reports since the last meeting.

* Threaded message organization, with arbitrary tree structure (root messages,
  replies with arbitrary depth).  You can focus on the subthread rooted at any
  message, or fold away the contents of a subthread to focus on the rest.
  (Currently the folds are not preserved across sessions / rerenders.)

* Tags: attached an arbitrary set of strings to a message.  Find other
  messages with the same tag by clicking on a tag.

* Search for posts by a particular user by clicking on their username.
  Search for your own posts in a group by clicking the "My Posts" button.

* Permanent URLs for all messages, groups, etc., for easy emailing etc.
  (but other than group name, not revealing, so only those with permission
  can open).  Links to other messages via specical coauthor:xxx syntax.
  Drag messages (via their arrow icon) into other messages to make such links.

* Files (another type of message) can be attached to other messages, as
  another type of reply.  Files can be replaced, and image/video files
  (including PNG, JPEG, SVG, MP4) are displayed inline.  (In the future,
  they and other visual file types such as PDF will be rendered by some
  kind of thumbnails.)

* Messages can start Unpublished, or after publication, Deleted; in either
  state, the message is hidden from non-authors.  (An author is someone who
  has edited the message.)  The default published state is initially true
  (so everyone sees the new message and live updates immediately), but can vary
  by user (e.g., if they are "shy" and only want to post finished thoughts).

* Email notifications for subscribed threads, clustering together all updates
  since the last email, with a maximum of 1 hour lag.
  Each user can specify in Settings whether they are, by default, subscribed
  to all threads or none.  Either way, the default can be overridden in the
  group view using the checkbox on the right (checked means "subscribed").
  Users can choose in Settings whether to receive notifications about their
  own edits.

* Time travel!  You can drag through history and see past versions.
  In general, there should be good, automatic history tracking of everything,
  including a not-yet-visible reparenting feature.

* Superuser operations (only for superusers):
  * Import from LaTeX document with figures attached as a ZIP file
  * Import from osqa's XML dump, including old edit history
  * Superdelete (permanently destroying a message including its history)
  * Setting the default sort for a group

## Permissions ##

To get started, you'll need to make a user who can grant privileges to other
users.  First, create the user on the web.  Then run a command like this from
`meteor mongo`:

```
meteor:PRIMARY> db.users.update({username: 'edemaine'}, {$set: {'roles.*': ['read', 'post', 'edit', 'super', 'admin']}})
WriteResult({ "nMatched" : 1, "nUpserted" : 0, "nModified" : 1 })
```

`*` means all groups, so this user gets the following permissions globally:

* read: see the group and read the messages (otherwise invisible)
* post: create new messages, replies, etc. in the group
* edit: modify other people's messages
* super: somewhat dangerous "super" operations like history-destroying
  superdelete, history-creating import, and the ability to see other users'
  deleted messages
* admin: administer over other users, in particular setting permissions
