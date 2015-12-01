Features so far:

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
with proper execution of Mathjax for LaTeX math.

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
