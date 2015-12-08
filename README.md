# Coauthor #

**Coauthor** is a tool for group collaboration, discussion, keeping track of
notes/results of meetings, etc.  Its primary goal is to ease multiauthor
collaboration on unsolved problems in theoretical computer science, so
e.g. you'll find LaTeX math support; hopefully it will have applications
in other fields too.

## Features So Far ##

* Live updates/redraw of everything, thanks to Meteor.  No more hitting
"reload".  If you're looking at a problem and someone posts/edits something,
you see it as quickly as they see their preview (roughly 1 second delay).

* Etherpad style (OT) real-time editing of messages, if people feel like
editing together (useful if e.g. working on a tex file together...).
The "stop editing" is maybe a little weird but not sure of a beter way.
When editing, you see near-instant updates from the other side(s).
And I can still keep track of authorship!  (more or less)
Also you get live previews with ~1-second delay, after the data has
round-tripped with the server.  (1 second delay is to reduce the crazy
number of "old versions" that will get saved -- server only pushes after
document has not changed for 1 second.)

* Two formats for rendering: HTML (sanitized) and Github-style Markdown,
with proper execution of MathJax for LaTeX math.  Easy to add other formats.

* Ace editor supports "regular" keybindings as well as Vim and (limited)
Emacs style.  (You may recall problem sessions where I needed to use Vim to
do rectangular selection... now it's built in!)

* Create new problem/discussion thread (currently not distinguished at all,
ignore those button labels -- should they be?); reply to message
(appending as last child).

* Messages are intended to be hidden to non-authors until they are marked
"Published".  (But not yet implemented.)  Is this a good idea?
Same as deleted, actually (also not implemented).

* Time travel!  You can drag through history and see past versions.
In general, there should be good, automatic history tracking of everything,
including a not-yet-visible reparenting feature.

* Import from osqa's XML dump, including old edit history!  Haven't snarfed
the image URLs/uploads yet though.

* Basic permissions model for protecting content, both reading and writing.
(See below.)

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
  superdelete and history-creating import
* admin: administer over other users, in particular setting permissions
