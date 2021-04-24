# Changelog

This file describes significant changes to Coauthor to an audience of
both everyday users and administrators running their own Coauthor server.
To see every change with descriptions aimed at developers, see
[the Git log](https://github.com/edemaine/coauthor/commits/master).
As a continuously updated web app, Coauthor uses dates
instead of version numbers.

## 2021-04-24

* Use Font Awesome icons for GitHub Flavored Markdown checkbox icons,
  fixing their rendering on Android.

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

## Older Changes

Refer to [the Git log](https://github.com/edemaine/coauthor/commits/master)
for changes older than listed in this document.
