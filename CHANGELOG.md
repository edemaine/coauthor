# Changelog

This file describes significant changes to Coauthor to an audience of
both everyday users and administrators running their own Coauthor server.
To see every change with descriptions aimed at developers, see
[the Git log](https://github.com/edemaine/coauthor/commits/main).
As a continuously updated web app, Coauthor uses dates
instead of version numbers.

## 2025-06-13

* Restore thicker strikethrough styling (`~~text~~`, `<s>text</s>`) on Firefox

## 2025-03-17

* Fix Since clustering by thread when multiple threads sort identically
  [[#647](https://github.com/edemaine/coauthor/issues/647)]

## 2025-03-06

* Improve performance of live view (downloads just the necessary messages)
* Improve performance via enabling Meteor oplog tailing for more queries

## 2025-03-05

* Improve performance by disabling oplog tailing on GridFS chunks
* Update to Meteor 2.16.0
* Upgrade DOMPurify library which fixes an XSS vulnerability
* Edit button finally looks right

## 2025-02-11

* Preserve whitespace in Markdown \`backticks\`, LaTeX `\verb`,
  and HTML `<code>`
* Users search ignores spaces at beginning or end
  (helpful when copy/pasting names)

## 2025-02-10

* Fix superuser's ability to manually delete an internal file via `deleteFile`
  [[#279](https://github.com/edemaine/coauthor/issues/279)]

## 2025-02-06

* Remove duplicate file description in unrendered files (non-images/videos/PDFs)
* Upgrade KaTeX which fixes a likely irrelevant XSS vulnerability

## 2025-01-15

* Prevent repeating password in full-name field when signing up for account
* Fix clipping of Rotate and File dropdowns above image
  [[#627](https://github.com/edemaine/coauthor/issues/627)]
  by moving them after description preview
  (also improving side-by-side preview)
* Upgrade DOMPurify library which fixes some XSS vulnerabilities

## 2024-08-12

* Fix embedding of historical images (internal files)

## 2024-07-10

* Security fix for pdfjs, fixing [vulnerability to malicious PDF](https://github.com/advisories/GHSA-wgrm-67xf-hhpq)

## 2023-12-21

* You can now select and copy text from PDFs.
* Clicking on a link in PDF now draws an arrow at the specific location
  linked to, in addition to flipping to the relevant page.

## 2023-12-20

* Fix the wrong page's PDF links sometimes showing up when quickly flipping
  through the pages of a PDF file, especially for slow-to-render pages.
  [[#534](https://github.com/edemaine/coauthor/issues/534)]

## 2023-12-18

* PDFs now support typing a page number manually,
  which makes it easier to navigate large documents.
  [[#346](https://github.com/edemaine/coauthor/issues/346)]
* PDFs remember your previous page when you click on a link,
  adding back/forward navigation buttons similar to browser back/forward.
* <kbd>+</kbd> and <kbd>-</kbd> keys now advance pages in the current PDF.
  (Click or mouse over a PDF to make it the current PDF.)

## 2023-12-17

* Superusers can now make private replies (e.g. for student feedback)
  from the "Reply/Attach" dropdown.

## 2023-12-14

* `\begin{tabular}` improvements:
  * `p{width}`, `m{width}`, and `b{width}` columns supported
  * `*` repetitions supported: `*3c` is shorthand for `ccc`,
    `*3{lr}` is shorthand for `lrlrlr`,
    `*{10}{c}` is shorthand for `cccccccccc`.
* Copy/pasting a URL from a message no longer adds extraneous zero-width spaces
* `\verb|$|` now works both inside and outside math mode

## 2023-12-05

* Remove small (100ms) race where Stop Editing could lose your changes

## 2023-11-21

* Only cluster by leading tags in the sort order, so if you click to sort by
  e.g. Updated then there's no longer awkward clustering by repeated tags.
* Search improvements: [[#29](https://github.com/edemaine/coauthor/issues/29)]
  * Search no longer supports quoting phrases with single quotes, so that it's
    easier to search for possessives (e.g. `Erik's`).
    [[#638](https://github.com/edemaine/coauthor/issues/638)]
  * Search now sorts by the group's default sort, instead of by title.
  * Fix escaping search queries with backslash:
    `\:`, `\"`, `\|`, `\(`, `\)`, `\\`
  * Newly allow escaping of `*` with `\*`
* Author view no longer lists messages multiple times

## 2023-11-17

* Fix scrolling to a message when clicking on it in table of contents
  (a long-standing but rare bug).
  [[#608](https://github.com/edemaine/coauthor/issues/608)]

## 2023-11-15

* Support `\begin{hint}` / `\begin{hint+}` environments (for problem hints).
* Support extra text after theorem-like environments, for finer control.
  For example, `\begin{theorem 1}` produces "Theorem 1", and
  `\begin{proof sketch}` produces "Proof sketch".
  By contrast, optional arguments add parentheses:
  `\begin{theorem 1}` produces "Theorem (1)", and
  `\begin{proof}[sketch]` produces "Proof (sketch)".
* `\begin{tabular}` improvements:
  * Skip over `\&`, HTML tags/character codes, and braced content,
    which makes it possible to include URLs with `&`s.
  * Fix column computations when using both `\multirow` and `\multicolumn`
    (in separate cells).

## 2023-11-01

* Support `\begin{remark}` and `\begin{note}` theorem-like environments,
  without the enlargement that theorem environments normally get.
  `\begin{example}` is also no longer large.

## 2023-10-30

* Warn about private images inlined within public messages
  [[#635](https://github.com/edemaine/coauthor/issues/635)]
* Warn about deleted/unpublished images only when inlined within
  deleted/unpublished messages

## 2023-10-18

* Simplify and improve dragging/pasting behavior of Coauthor messages/images:
  * Dragging or pasting an embedded image, or a message with an embedded image,
    will inline the image only if you're dragging/pasting at the beginning
    of a line (possibly with indentation).
  * When dragging a message (not embedded image), the message must also have
    no body and no children to be considered for inlining.

## 2023-10-16

* Raw `coauthor:...` links now get rendered with message title when available
* Improve dragging/pasting behavior of Coauthor messages/images:
  * Dragging or pasting a message's embedded image will always inline the image
    (`![](coauthor:...)` in Markdown, `\includegraphics{coauthor:...}`
    in LaTeX, and `<img src="coauthor:...">` in HTML).
  * Dragging or pasting a message that has an embedded image will inline the
    image if the message has no body (description) and no children,
    and the cursor is at a space or table delimiter.

## 2023-10-13

* New LaTeX forms of
  [HTML `<details>`/`<summary>` tags](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/details):
  * `\begin{details}...\end{details}` or `\begin{+}...\end{+}` to make basic
    `<details>...</details>` text that's hidden until clicked.
  * `\begin{details}[header]` or `\begin{+}[header]` to change the default
    "Details" text to desired header.
  * `\begin{proof+}`, `\begin{theorem+}`, etc. to make a proof that's
     hidden with header "Proof", "Theorem", etc. (essentially shorthand for
     `\begin{+}\begin{proof}`).
* Fix multiple \$math\$ chunks connected only by punctuation
  [[#636](https://github.com/edemaine/coauthor/issues/636)]

## 2023-10-12

* Superusers can now start private threads (e.g. for course staff discussion)
  from the "New Thread" dropdown on the Group page
* Fix bugs in Since sorting
  [[#634](https://github.com/edemaine/coauthor/issues/634)]
* Private root messages now sort between minimized and deleted

## 2023-10-11

* Embedded images, videos, and PDFs now all generate warnings if the embedded
  message is unpublished or deleted, even with `https://coauthor` URLs.
  [[#633](https://github.com/edemaine/coauthor/issues/633)]
* Fix math sometimes being incorporated into a link (e.g. `$foo$.In`)

## 2023-10-05

* Image messages no longer "auto-fold" when they're embedded in another message
  when the image message has a body (description).
  [[#632](https://github.com/edemaine/coauthor/issues/632)]
* Fix bugs where message editor tries and fails to load, and never gives up.
  [[#631](https://github.com/edemaine/coauthor/issues/631)]
  [[#630](https://github.com/edemaine/coauthor/issues/630)]
* Fix paste enhancements (e.g. Coauthor URL simplification)
  when using multiple editor cursors (via <kbd>Ctrl</kbd>-click)
  [[#629](https://github.com/edemaine/coauthor/issues/629)]

## 2023-10-03

* When sorting a group by one or more tags (as the most significant sort),
  unpublished and pinned messages are sorted higher, and
  minimized and deleted messages are sorted lower, *within each tag cluster*.
  (Previously, this message status sorting was done at a global level.)
* Pinned messages get colored bright yellow in group view

## 2023-09-20

* Since view now sorts by group's default sort, instead of increasing title.
  [[#600](https://github.com/edemaine/coauthor/issues/600)]

## 2023-09-18

* Improve title sorting to ignore leading nonprinting characters:
  whitespace, `\`, entering math mode (`$`, `\(`, `\[`),
  starting Markdown formatting (`*`, `_`, `~~`, `` ` ``).

## 2023-09-14

* Fix clipping of Rotate and File dropdowns which made them nonfunctional
  [[#627](https://github.com/edemaine/coauthor/issues/627)]

## 2023-09-13

* Fix excess horizontal scrollbars in messages, especially with display math

## 2023-09-11

* More File UI redesign:
  [[#624](https://github.com/edemaine/coauthor/issues/624)]
  * "Extract File" lets you move an embedded file from a message
    into its own reply message.
  * "Extract File" from History view lets you copy an old embedded file
    into its own reply message.

## 2023-09-10

* File UI redesign:
  [[#624](https://github.com/edemaine/coauthor/issues/624)]
  * New "File" dropdown next to every embedded file description and when editing
  * Replaces old "Add File" and "Replace File" buttons
    * "Embed One File" makes clear that only one file can be embedded
    * You can drag and drop a file onto the File dropdown, like before.
  * You can now Remove a file, or Restore a previous version from History.
* Fix viewing old PDF files in History
* Fix sticky header in group view getting covered up by math in thread titles.

## 2023-09-07

* Fix sorting a group by multiple fields, some in reverse
  [[#623](https://github.com/edemaine/coauthor/issues/623)]
* Fix reactivity of fullname and email when administering Users

## 2023-09-06

* Rename replies from "Another" to "New".
  (In particular, makes more sense with threads with private replies.)

## 2023-08-12

* Editor no longer considers foreign (non-ASCII) characters spelling errors.
  (They are simply ignored, as the dictionary is English only.)
  [[#615](https://github.com/edemaine/coauthor/discussions/615)]

## 2023-07-19

* Regular messages can now gain a file attachment later in life, via a new
  Add File button.  Note that each message can still only have one file
  attachment (use more messages for more files, e.g. via Reply/Attach).
  Also, it's not yet possible to remove the file attachment.
  [[#588](https://github.com/edemaine/coauthor/issues/588)]
* Placement of Replace File button changed (and now matches Add File).

## 2023-06-18

* Fix for Safari 16.4+

## 2023-05-11

* New administrative interface for managing Users in a group
  * Split into multiple sections (members of various types
    vs. other users to add)
  * More consistent (and faster) layout of table
  * Initially show only latest 10 users, with buttons for more/all
  * Support for searching among users

## 2023-04-22

* Visual warning when embedding image that is deleted or unpublished,
  so unlikely to be visible to other users.
  [[#574](https://github.com/edemaine/coauthor/issues/574)]
* White border around images in dark mode is now thinner and
  no longer overlaps neighboring content.

## 2022-08-20

* Table of contents displays all message coauthors instead of creator.
  For more than two coauthors, it just shows last names.
  [[#607](https://github.com/edemaine/coauthor/issues/607)]
* Support folding of LaTeX `\section`, `\begin{itemize}`, etc.
  in Markdown format (not just LaTeX), as it supports this syntax too.
* Bug fixes in LaTeX folding
* Fix folding when changing between formats in message editor via
  [CodeMirror 5.65.8](https://codemirror.net/5/doc/releases.html)

## 2022-08-08

* Improve wording in email notifications for thread creation
  ("created thread" instead of "created root message in thread").

## 2022-07-27

* URLs with "false Markdown" in them fixed thanks to updated markdown-it
  [[#426](https://github.com/edemaine/coauthor/issues/426)]
* Small message editor bug fixes via
  [CodeMirror 5.65.7](https://codemirror.net/5/doc/releases.html)

## 2022-07-04

* Better copy/pasting behavior with messages containing mathematics,
  thanks to KaTeX 0.16.0.
* [Link](README.md#user-tips) to better ways to input accented characters

## 2022-04-30

* Search now supports parentheses for mixing AND and OR queries arbitrarily.
  For example, `always (this | that)` searches for messages containing
  both word `always` and either `this` or `that`.

## 2022-04-29

* When filling in the search box in a thread view,
  the search is automatically restricted to that thread.
  [[#282](https://github.com/edemaine/coauthor/issues/282)]
* New search operator `root:id` restricts to messages within the thread
  rooted at message with specified `id`.
  [[#29](https://github.com/edemaine/coauthor/issues/29)]

## 2022-04-23

* Switch to [DOMPurify](https://github.com/cure53/DOMPurify) HTML sanitizer,
  which should make Coauthor faster overall and permit some more (safe)
  HTML/SVG features than before.  One new restriction is that SVG `<use>`
  can only use local hrefs, but this is necessary for security.
  [[#508](https://github.com/edemaine/coauthor/issues/508)]
* Further reduction in JavaScript bundle size, for faster loading of Coauthor.
  [[#218](https://github.com/edemaine/coauthor/issues/218)]

## 2022-04-21

* Fix "Replace File" button and improve behavior of clicking on message header
  to highlight corresponding item in Table of Contents.
  [[#598](https://github.com/edemaine/coauthor/issues/598)]

## 2022-04-11

* Hovering over a message highlights the corresponding item
  of the table of contents, or if that item is out of visual range,
  the relevant border.
  [[#598](https://github.com/edemaine/coauthor/issues/598)]
* Hovering over a table-of-contents item highlights the corresponding message.
  [[#552](https://github.com/edemaine/coauthor/issues/552)]

## 2022-03-22

* Messages can now be pinned to highlight them as "important"
  (like the opposite of "minimized").
  Pinned messages get a pin icon and yellow color.
  Pinned root messages get their threads sorted to the top in group view.
  [[#599](https://github.com/edemaine/coauthor/issues/599)]
* The icons for whether a message is being edited or is a file
  now show up in the group view.

## 2022-03-20

* Messages can now use internal hash links.
  Markdown headings get automatic `id`s (like GitHub); for example,
  `## Here` becomes `<h2 id="here">Here</h2>`.
  Alternatively, you can add an `id` attribute to any HTML tag.
  Then you can link to this `id` via `<a href="#here">` or `[link](#here)`
  in Markdown.
  The `id` gets prefixed by the message ID and an underscore,
  to avoid `id` conflicts between messages.
  You can link to a different message's internal link via `#OTHERID_here`.
  [[#586](https://github.com/edemaine/coauthor/issues/586)]

## 2022-03-17

* Table of contents highlights all messages that are visible in the main view,
  so it's much easier to tell where you are.
  The color is more intense for messages fully in view.
  [[#597](https://github.com/edemaine/coauthor/issues/597)]
* Clicking on a message header scrolls the table of contents to align the
  corresponding item, to the extent possible, and pulses that item.
  [[#598](https://github.com/edemaine/coauthor/issues/598)]
* Scrolling to messages or table-of-contents items now respects the browser's
  `prefers-reduced-motion` setting, avoiding smooth scrolling in that case
  for improved accessibility.

## 2022-03-15

* Group view's header restyled, with headings sticking to
  the top of the page as you scroll.
* Group view lists all features that messages are sorted by, so you can more
  easily control this order.  You can drag features to re-order priority,
  click on features to flip increasing vs. decreasing, remove features,
  add features (as usual), and reset to default view.
* Clicking on a header like Updated will now sort by that as primary.
  When used with tag sorting, this will show more clusters than is optimum,
  but is useful for seeing what threads were updated most recently.
  Re-order the sorts to put tags in front if you want the fewest clusters.

## 2022-03-13

* Notifications now show which tags were added/removed/changed.
  [[#520](https://github.com/edemaine/coauthor/issues/520)]
* Many bug fixes and improvements around message tag values.
  [[#520](https://github.com/edemaine/coauthor/issues/520)]

## 2022-03-12

* Tags on messages can now have values.  For example, each thread root can have
  a `category`, `week`, or `type` tag with a value.  The group view can then be
  clustered by one or more of these values, using the new "By tag" dropdown.
  [[#520](https://github.com/edemaine/coauthor/issues/520)]
  [[#522](https://github.com/edemaine/coauthor/issues/522)]
* The group view can now be sorted by multiple features at once, like a
  spreadsheet. Click the least significant feature to sort by first,
  then click each subsequent feature.
  The URL now has a sequence of `+`s and `-`s to indicate the various sorts.
  [[#349](https://github.com/edemaine/coauthor/issues/349)]

## 2022-03-11

* Allow superusers to add arbitrary users (not necessarily group members)
  as coauthors or private-message visibility.
  This is useful when prewriting group content before releasing it to users.
  [[#503](https://github.com/edemaine/coauthor/issues/503)]

## 2022-03-10

* Restore human-readable date formatting
* Fix file uploads for partial members

## 2022-03-04

* Rewrote the
  [file uploading system](https://github.com/edemaine/meteor-file-collection)
  (which was necessary for modern Meteor, MongoDB, etc.).
  If you're running your own server, you may need to execute some of the
  following MongoDB commands to let Coauthor rebuild indexes:

  ```js
  db.users.dropIndexes()
  db.fs.files.dropIndexes()
  db.fs.chunks.dropIndexes()
  db.fs.locks.drop()  // no longer needed
  ```

  This also adds support for MongoDB Atlas.
  [[#472](https://github.com/edemaine/coauthor/issues/472)]
* More improvements to automatic image reloading when file gets replaced.
  [[#163](https://github.com/edemaine/coauthor/issues/163)]
* Fix import functionality

## 2022-02-20

* Users view should be faster, especially reacting to button presses,
  thanks to SolidJS.
  [[#595](https://github.com/edemaine/coauthor/issues/595)]

## 2021-11-13

* Fix <kbd>s</kbd> key not working in message editor on iOS

## 2021-11-12

* Fix page title when switching between groups
  [[#587](https://github.com/edemaine/coauthor/issues/587)]

## 2021-10-21

* Fix bug when switching between the Users view of multiple groups
  (partial access to messages didn't update)

## 2021-10-14

* Clarify that `author` view lists posts by and @mentioning the user

## 2021-09-29

* Fix bug in finding editor folds when editing a message in LaTeX mode that
  uses `\begin{foo}` where `foo` has weird characters in it.

## 2021-09-14

* Fix behavior of links to messages with correct group name
  when message gets moved across groups.

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
  Become/Leave Superuser button) via the keyboard shortcut <kbd>s</kbd>.

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
