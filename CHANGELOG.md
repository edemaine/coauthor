# Changelog

This file describes significant changes to Coauthor to an audience of
both everyday users and administrators running their own Coauthor server.
To see every change with descriptions aimed at developers, see
[the Git log](https://github.com/edemaine/coauthor/commits/main).
As a continuously updated web app, Coauthor uses dates
instead of version numbers.

## 2021-09-10

* Fix accidental Reply buttons when user has no Post permission
  (at the bottom of message with children).
  [[#585](https://github.com/edemaine/coauthor/pull/585)]

## 2021-07-07

* Improve automatic image reloading when file gets replaced.
  [[#163](https://github.com/edemaine/coauthor/issues/163)]

## 2021-06-16

* Tweak dark-mode scrollbar colors on Firefox mode so they don't disappear
  when clicking on them.

## 2021-06-13

* Further speed up Coauthor server restart.

## 2021-06-12

* Email notifications include message body when message becomes visible for
  the first time to a user (e.g. via Actions / Publish).
  [[#438](https://github.com/edemaine/coauthor/issues/438)]
* Avoid duplicate email notifications, even under heavy server load.
  [[#562](https://github.com/edemaine/coauthor/issues/562)]

## 2021-06-01

* Fix `\colorbox` which allows specifying background colors in LaTeX and
  Markdown formats: `\colorbox{color}{text}`.
* Allow `<sup>` and `<sub>` for HTML superscripts and subscripts in messages.
  [[#572](https://github.com/edemaine/coauthor/issues/572)]

## 2021-05-29

* Add dark mode for PDF documents by inverting and hue-shifting 180 degrees.
  Set your default preference in Settings, and/or toggle individual
  documents via new sun/moon icon.
  [[#569](https://github.com/edemaine/coauthor/issues/569)]
* Fix bug when following links between different Coauthor groups
* Fix PDF/image resizing when toggling TOC
  [[#568](https://github.com/edemaine/coauthor/issues/568)]

## 2021-05-19

* Support for `\begin{example} ... \end{example}` theorem-like environment.
  [[#563](https://github.com/edemaine/coauthor/issues/563)]
* At-mentions no longer expand in verbatim contexts
  [[#533](https://github.com/edemaine/coauthor/issues/533)],
  and can be escaped via `\@`.
  [[#563](https://github.com/edemaine/coauthor/issues/563)]
* Table of contents won't be completely folded when zooming into/focusing on
  a minimized message.
  [[#564](https://github.com/edemaine/coauthor/issues/564)]

## 2021-05-08

* Table of contents links are now direct links to messages (instead of hash
  links), so you can copy them to clipboard and paste them into a message, or
  control/shift/middle-click to open them in a new window.
* Fix an old bug where the message body editor sometimes shows
  `loading...` forever.
  [[#559](https://github.com/edemaine/coauthor/issues/559)]

## 2021-05-06

* Improve scrolling behavior when using browser back and forward.
  [[#557](https://github.com/edemaine/coauthor/issues/557)]

## 2021-05-04

* Small visual improvements: navbar extends the full page width,
  reduced space between messages and table of contents.
* Preserve which messages were folded or in Raw view across server restarts.
* Fix accidental scrolling when adding emoji responses.

## 2021-05-02

* When clicking on a link to a message within the currently visible
  (sub)thread, scroll to the message instead of zooming in to its subthread.
  If you'd like to zoom in, you can click on the Zoom In/Focus button.
  [[#553](https://github.com/edemaine/coauthor/issues/553)]
* Fix scrolling to message specified by hash in URL.
  [[#553](https://github.com/edemaine/coauthor/issues/553)]
* Automatically focus on title of message when we start editing it,
  including when we start a new reply or thread.

## 2021-04-28

* Improve table of contents layout
  [[#486](https://github.com/edemaine/coauthor/issues/486)]
  and highlighting of top message
  [[#552](https://github.com/edemaine/coauthor/issues/552)]
* You can now fold a section of the table of contents
  by clicking on one of the vertical lines.
  [[#551](https://github.com/edemaine/coauthor/issues/551)]

## 2021-04-26

* Display equations now get their own horizontal scrollbars, for easier
  scrolling within large messages.

## 2021-04-25

* Fix embedding of PDF Coauthor files within a message.
  (This has been broken since 2021 because of the React port.)

## 2021-04-24

* Support empty `{align}` environments again (thanks to KaTeX 0.13.3).
* Use Font Awesome icons for GitHub Flavored Markdown checkbox icons,
  fixing their rendering on Android.
* Rename main branch from `master` to `main`.
  The link to this Changelog has changed (but the old link redirects).

## 2021-04-21

* Equation numbering with `\begin{align/alignat/equation/eqnarray/gather}`
  environments.  Use `\begin{align*}` etc. to prevent equation numbers.
  (Further incorporating KaTeX 0.13.)
* Fix horizontal scrollbar when editing wide formulas (say)
  in side-by-side mode.
* When starting a New Thread, automatically focus on the message title
  for more immediate typing.

## 2021-04-19

* Add support for LaTeX amsmath environments `\begin{alignat}`,
  `\begin{gather}`, and `\begin{CD}` (thanks to KaTeX 0.13).
  [[#531](https://github.com/edemaine/coauthor/issues/531)]

## 2021-04-18

* Custom scrollbars should look nicer especially in dark mode.
  [[#548](https://github.com/edemaine/coauthor/issues/548)]

## 2021-04-17

* Syntax highlighting should fail less often now, by telling `highlight.js`
  to keep highlighting even if it encounters what it considers a syntax error.

## 2021-04-16

* Further improved visual styling of GitHub Flavored Markdown checkboxes in
  lists, now using Unicode symbols instead of actual disabled checkboxes.
  It's now much easier to distinguish the checked vs. unchecked state.
* Further speed up Coauthor server restart.

## 2021-04-06

* Improved visual styling of GitHub Flavored Markdown checkboxes in lists,
  in particular rendering both a number and a checkbox for ordered lists,
  and fix multiparagraph checkbox items.
  [[#545](https://github.com/edemaine/coauthor/issues/545)]

## 2021-04-02

* You can use GitHub Flavored Markdown checkboxes in lists (again) via
  `* [ ]` and `* [x]`.  (The checkboxes can't be clicked,
  but are still useful visual indicators for to-do lists.)
* You can see and add emoji responses to messages while editing them.
  (This restores functionality removed on 2020-11-02 in an experiment for
  [#488](https://github.com/edemaine/coauthor/issues/488).)
  [[#543](https://github.com/edemaine/coauthor/issues/543)]
* Messages with file attachments now consistently link to the latest version
  in non-history view, and to a specific version in history view.
  (This bug was introduced during the React port.)
* Raw view of messages with image attachments now shows a clean `<img>`
  embed command, without the file size which can get out of date.
  [[#536](https://github.com/edemaine/coauthor/issues/536)]

## 2021-03-29

* For server administrators, the backup script in `.backup/backup.sh` got
  refactored to be easier to configure to your specific setup (server,
  backup directory, backup server, etc.).  It's also now easier to adapt to
  other servers like Cocreate and Comingle.

## 2021-03-26

* Message reply button labels and tooltips are somewhat improved:
  "Reply All" became "Reply" for symmetry / less confusion,
  tooltips use more adjectives to clarify what each button will do, and
  buttons that generate private replies are colored the private color.
* Coauthor server restart time should be much faster, via a better choice
  for index of notifications.
* If the Coauthor server has restarted and you have changes that would be lost
  in reload, you now get an alert at the bottom of the window
  (in addition to alerts within the relevant messages).

## 2021-03-25

* Markdown lists can start at a number other than 1 (e.g. `0.` or `2.`).
  (Later numbers still automatically increment by 1, whatever you write,
  following the CommonMark spec.)
* Coauthor server restarts no longer cause you to lose unsaved changes in a
  message editor (by reloading the page).  Instead, Coauthor will prompt you
  to save your unsaved changes in another file or your clipboard, manually
  reload, and put your changes back in.  Coauthor will also warn you before
  you manually close the tab or reload a page that has unsaved changes.
  [[#125](https://github.com/edemaine/coauthor/issues/125)]
* Server administrators: Automatic database format upgrade from older version
  of Coauthor is no longer always automatic; it is controlled by the
  presence/absence of the `COAUTHOR_SKIP_UPGRADE_DB` environement variable
  in `.deploy/mup.js`; see [INSTALL.md](INSTALL.md).  This speeds up
  typical server restarts which don't need database upgrades.
* Server administrators: The default MongoDB version is now 4.4.4.
  If you already have MongoDB installed, the version shouldn't change.

## 2021-03-24

* Fix the wrong page's PDF links sometimes showing up when quickly flipping
  through the pages of a PDF file.
  [[#534](https://github.com/edemaine/coauthor/issues/534)]

## 2021-03-19

* Allow line breaks in math with punctuation after it, like `$O(m+n)$,`
  (which, as in LaTeX, can break after `+`).
  [[#465](https://github.com/edemaine/coauthor/issues/465)]
* Fix handling of math in HTML comments like `<!--$math$-->`.
  [[#535](https://github.com/edemaine/coauthor/issues/535)]

## 2021-03-09

* If a user edits a message, then removes themselves as a coauthor on the
  message, you'll see their name in parentheses in History view.

## 2021-03-05

* Fix incorrect labels and tags on the root message in a zoomed-in view of
  a subthread.

## 2021-03-04

* Improvements to Coauthor's `\def` processing (when outside math mode):
  * `\foobar` no longer triggers expansion of a defined `\foo` macro
  * You can use `\foo{}` or `{\foo}` to avoid eating the whitespace
    after `\foo`.

## 2021-03-03

* Protected messages no longer have a "Protected" label (in particular in the
  group view).  Instead, there's a lock icon on the Edit button of the message,
  and the button is disabled if the user can't edit the message
  (they aren't a coauthor or a superuser).
  [[#530](https://github.com/edemaine/coauthor/issues/530)]
* Edit and Stop Editing buttons have tooltips to explain their behavior,
  in particular that messages are automatically saved and thereby visible
  to everyone immediately (unless unpublished or deleted).
* You can now create a new thread in a new browser tab by middle clicking or
  <kbd>Ctrl</kbd> clicking one of the New Root Message buttons.
  [[#482](https://github.com/edemaine/coauthor/issues/482)]

## 2021-03-02

* Fix all messages disappearing when setting "Preview while editing" to "No".

## 2021-03-01

* Superusers can now toggle superuser mode (the equivalent of the
  Become/Leave Superuser button) via the keyboard shortcut `s`.

## 2021-02-25

* Email notifications now use all-caps adjectives like DELETED, UNPUBLISHED,
  and PRIVATE so that they stand out more.
* Messages can now be marked as Protected, meaning that only coauthors and
  superusers can edit the message.  This does not affect the ability to see
  the message, nor the ability to reply (including emoji responses).
  This is useful for preventing user error, e.g., to avoid accidentally adding
  coauthors to root messages to threads with private replies (e.g. solved
  problems), or to avoid accidentally unminimizing a minimized hint message.
  [[#507](https://github.com/edemaine/coauthor/issues/507)]

## 2021-02-22

* Table of contents now correctly underlines messages with math in their titles.
* "Add emoji response" tooltip closes after selecting an emoji to add.
* Fix navbar dropdown menus getting covered up by the table of contents.

## 2021-02-20

* Fix errors in `` ` `` processing.
  [[#527](https://github.com/edemaine/coauthor/issues/527)]

## 2021-02-18

* Clicking on a message in the table of contents scrolls to that message
  (as it used to).

## 2021-02-16

* Replace group-level "Pose New Problem / Discussion" button with
  "New Thread" dropdown, making it easy to start an (un)published thread.
  [[#524](https://github.com/edemaine/coauthor/issues/524)]
* Replying to an unpublished or deleted message makes an unpublished or
  deleted reply message.
  [[#525](https://github.com/edemaine/coauthor/issues/525)]

## 2021-02-15

* Prevent deleting or unpublishing messages that you're not a coauthor on.
  This prevents accidental loss of access to a message, where you accidentally
  delete or unpublish a message and then can't see it anymore, so can't fix
  your mistake.  (If you need to work around this, you can always become a
  coauthor (or superuser) before deleting or unpublishing.)
* `https://coauthor.../group/stats/me` is now a link to your own stats
  (`me` expands to your own username).  Useful for sending the link to others.

## 2021-02-12

* Replace Reply and Attach buttons with a Reply/Attach menu,
  making it harder to accidentally add a new reply and
  easier to start an (un)published reply.
  [[#523](https://github.com/edemaine/coauthor/issues/523)]
* Add more tooltips to Reply options to clarify what they do.
  [[#396](https://github.com/edemaine/coauthor/issues/396)]
* Next/previous message buttons at top of a thread now show the target
  message title, including Markdown/LaTeX formatting.

## 2021-02-04

* Keyboard shortcut <kbd>t</kbd> toggles whether to show the Table of Contents
  (so that you don't have to scroll up to toggle)
* Email notifications now color adjectives like deleted, unpublished,
  and private so that they stand out more.

## 2021-01-30

* Support embedding Coauthor files into Cocreate boards
  (e.g., via copy/paste)
* Highlight at-mentions that refer to you within email notifications
  [[#384](https://github.com/edemaine/coauthor/issues/384)]

## 2021-01-29

* Highlight at-mentions that refer to you, so that you can more easily
  see people mentioning you while scrolling.
* Prevent `$` from triggering math mode within Markdown code blocks,
  so e.g. `` `$x$` `` doesn't italicize the `x`.
  [[#387](https://github.com/edemaine/coauthor/issues/387)]
* Security fix for HTML in user's real names; and
  forbid Markdown special characters from usernames.
  [[#516](https://github.com/edemaine/coauthor/issues/516)]

## 2021-01-25

* Allow manual toggling of Table of Contents (by clicking on the header at the
  top of a thread), so you can show it on narrow displays or hide it on
  wide displays.
  [[#324](https://github.com/edemaine/coauthor/issues/324)]

## 2021-01-24

* Search supports notation `by:me` to find messages by yourself,
  and `emoji:@me` to find messages that you responded to with emoji:
  `me` automatically expands to your username.
* Prevent a nonsuperuser from making private the root message of a thread that
  has public and private replies allowed, because root message isn't a reply.
* Add tooltips explaining all remaining Action buttons
  [[#396](https://github.com/edemaine/coauthor/issues/396)]

## 2021-01-23

* Search supports `by:username` to find messages
  coauthored by a particular username.
  [[#29](https://github.com/edemaine/coauthor/issues/29)]
* Search supports `emoji:heart` to find messages with heart emoji responses,
  `emoji:@username` to find messages with emoji responses by a particular
  username, and `emoji:heart@username` to find heart emoji responses by a
  particular username.
  [[#29](https://github.com/edemaine/coauthor/issues/29)]
* Search supports `isnt:` and `not:` short forms for `-is:`.
  For example, `isnt:file` matches messages that aren't file messages.
  [[#29](https://github.com/edemaine/coauthor/issues/29)]
* Fix highlighting of emoji responses that include yourself.
  [[#511](https://github.com/edemaine/coauthor/issues/511)]
* Prevent history slider tooltips from overlapping with content
  or falling outside the window.
* Fix History view not loading correctly on second try.

## 2021-01-21

* Authorship and Access list major revamp.
  [[#503](https://github.com/edemaine/coauthor/issues/503)]
  * Every message now has an explicit **coauthor list** which you can
    manipulate: add to it to represent who you worked with in a live session,
    or remove your own name if you're just fixing a typo.
    (Only superusers can remove other people who did actual edits.)
  * Private messages have an **access list** for who to share the message with,
    which activates only when the message is published (so you can still draft
    private messages, accessible only to the coauthors).
  * At-mentions no longer have any effect on who can see a message (but they
    will trigger automatic suggestions for people to add to the access list
    in a private message).  Old at-mentions are converted to coauthorship.

## Older Changes

Refer to [the Git log](https://github.com/edemaine/coauthor/commits/main)
for changes older than listed in this document.
