# Coauthor #

**Coauthor** is a tool for group collaboration, discussion, keeping track of
notes/results of meetings, etc.  Its primary goal is to ease multiauthor
collaboration on unsolved problems in theoretical computer science, so
e.g. you'll find LaTeX math support; hopefully it will have applications
in other fields too.

![Coauthor screenshot](http://erikdemaine.org/software/coauthor_large.png)

## Features So Far ##

* **Live updates**/redraw of everything, thanks to
  [Meteor](https://www.meteor.com/).
  If you're looking at a problem and someone posts/edits something,
  you see it as quickly as they see their preview (roughly 1-second delay).
  You should never have to hit "reload" (except in case of a bug).

* **Real-time editing** of messages in the style of Google Docs/EtherPad
  (Operational Transforms), if people feel like editing together
  (useful if e.g. working on a proof together).
  When editing, you see near-instant updates from the other side(s).
  Keep track of authorship by who is in edit mode at the time.
  Also you get live previews with ~1-second delay, after the data has
  round-tripped with the server.  (1 second delay is to reduce the crazy
  number of "old versions" that will get saved -- server only pushes after
  document has not changed for 1 second.)

* Three **formats** for writing messages (and easy to add additional formats).
  All formats support LaTeX math (via `$...$`, `$$...$$`, `\(...\)`, `\[...\]`,
  or `\begin{align/equation/eqnarray}...\end{align/equation/eqnarray}`)
  via [KaTeX](https://khan.github.io/KaTeX/), so math mode supports
  [this list of supported functions](https://khan.github.io/KaTeX/function-support.html).
  Macros defined with `\gdef` can be used throughout one message.

  * [Github-style Markdown](https://guides.github.com/features/mastering-markdown/)
    (default), e.g., `*italic*`, `**bold**`, `~~strikethrough~~`,
    `# Heading`, `## Subheading`, \`code\`, `> Block quote`,
    <code>\`\`\`multiple lines of code\`\`\`</code>,
    links via `[text](url)`, images via `![caption](url)`,
    lists via `*` or `1.`, tables, etc.
    Also supports all LaTeX commands listed below that start with a letter
    (notably, not accents) and math mode.
  * LaTeX, limited.  Beyond extensive math mode support (see below),
    the following features are supported in text mode; feel free to ask
    for more.  `%...`, `\def\macro{...}`, `\let\macro=\mac`, `\protect`,
    `\emph`, `\textit`, `\textup`, `\textnormal`, `\textrm`, `\textlf`,
    `\textmd`, `\textbf`, `\textsf`, `\texttt`, `\textsc`, `\textsl`,
    `\em`, `\itshape`, `\upshape`, `\rmfamily`, `\lfseries`, `\mdseries`,
    `\bfseries`, `\rmfamily`, `\sffamily`, `\ttfamily`, `\scshape`, `\slshape`,
    `\rm`, `\normalfont`, `\md`, `\bf`, `\it`, `\sl`, `\sf`, `\tt`, `\sc`,
    `\bfseries`, `\itseries`, `\mdseries`, `\sffamily`, `\slshape`,
    `\scshape`, `\ttfamily`, `\uppercase`, `\MakeTextUppercase`,
    `\lowercase`, `\MakeTextLowercase`, `\underline`,
    `\textcolor{color}{text}`, `\colorbox{backcolor}{text}`,
    `\url`, `\href{url}{text}`, `\pdftooltip{hovertext}{text}`,
    `\raisebox{amount}{text}`, `\par`,
    `\BY{...}`, `\YEAR{...}`,
    `\chapter`, `\section`, `\subsection`, `\subsubsection`, `\footnote`,
    `\includegraphics[width/height/scale]{url}`,
    `\smallskip`, `\medskip`, `\bigskip`, `\noindent`,
    `\"`, `\'`, ```\` ```, `\^`, `\~`, `\=`, `\c`, `\v`, `\u`, `\H`,
    `\textasciitilde`, `\textasciicircum`, `\textbackslash`,
    `\textellipsis`, `\dots`, `\ldots`,
    `\&`, `\$`, `\{`, `\}`, `\%`, `\#`, ``` `` ```, `''`,
    `~`, `--`, `---`, `{`, `}`, `\\`, `\item`;
    `\begin/\end` for environments `verbatim`, `enumerate`, `itemize`,
    `quote`, `tabular` (basic),
    `equation`, `eqnarray`, `align`,
    `problem`, `question`, `idea`, `theorem`, `conjecture`, `lemma`,
    `corollary`, `fact`, `observation`, `proposition`, `claim`, `proof`.
  * HTML, sanitized.  The following tags are allowed; feel free to ask for
    more.  `<h1>`, `<h2>`, `<h3>`, `<h4>`, `<h5>`, `<h6>`,
    `<blockquote>`, `<p>`, `<div>`, `<span>`,
    `<a href/name/target>`, `<ul>`, `<ol start>`, `<nl>`, `<li>`, `<b>`,
    `<strong>`, `<i>`, `<em>`, `<u>`, `<s>`, `<strike>`, `<del>`, `<code>`,
    `<hr>`, `<br>`, `<table>`, `<thead>`, `<caption>`,
    `<tbody>`, `<tr>`, `<th>`, `<td>`, `<pre>`,
    `<img src/alt/width/height>`, `<video controls>`, `<source src>`;
    attributes `title`, `style`, `class`, `aria-*`.
    Also supports LaTeX math mode.

* [CodeMirror editor](http://codemirror.net/) supports syntax highlighting,
  block folding, bracket matching, line numbering, light and dark themes,
  [spell checking](https://github.com/NextStepWebs/codemirror-spell-checker),
  "regular" keybindings as well as Vim and Emacs keybindings
  (if you've ever needed rectangular selection for e.g. ASCII art).

* Messages are organized by **groups** (intended to correspond to groups of
  people who meet), so it's easy to share material with everyone in the group.
  But it's also possible to share part of a group (only certain threads)
  with specific users, for visitors or paper merges etc.

* **Sorting** of threads within a group by title, creator, creation date,
  last update, number of posts, number of positive emoji responses, or whether
  subscribed (by clicking on the corresponding column, once for default sort
  order and again for opposite sort order).  Intelligent handling of numbers
  while sorting, e.g. "9." comes before "10.".  Deleted messages always sort
  to the very bottom; minimized messages always sort near the bottom; and
  unpublished messages always sort near the top.

* "**Live Feed**" to watch messages as they get changed/posted.  Useful for
  projecting the latest activity onto a big screen while a group is gathered
  and some are maybe editing.

* "**Catchup on Recent Posts**" to see all messages since a particular date/time
  (including relative specifications like "1 week" or "12 hours").
  Useful for progress reports since the last meeting.

* **Threaded** message organization, with arbitrary tree structure (root
  messages, replies with arbitrary depth).  You can **focus** on the subthread
  rooted at any message (click on the arrow), or **fold** away the contents of
  a subthread to focus on the rest (click on the minus sign).
  Folding with the minus/plus sign is a local and temporary change (resets when
  reloading the page), while **minimizing** the message makes it start out
  folded for all users (e.g., when a discussion/question resolves and is
  no longer important, but you want to preserve it for future reference).

* **Dragging** messages to change the parentage/hierarchy, or move their
  position within their parent.  You must drag *onto* the table of contents
  on the right; you can drag *from* the table of contents, or from the
  right-arrow of a message in the main view.
  Dragging directly onto a message makes the dragged message the last child,
  while dragging onto the slot before a message makes the dragged message the
  immediately preceding sibling.  Dialog confirms move.

* **Tags**: attach an arbitrary set of strings to a message.  Find other
  messages with the same tag by clicking on a tag.

* **Emoji** for super-short responses that show appreciation but don't cause
  email notifications or take up much space.  (Like Github and Slack.)
  Hover over an emoji to see a list of people who added the emoji; click to
  toggle your own status.  Emoji are positive (purple) or negative (red).
  Positive emoji on root messages are counted on the group page, enabling
  a simple voting system for e.g. which problems to work on. 

* **Search** across an entire group, or across all groups,
  for posts by keywords using the search bar at the top.
  Search for a word as a (whole) `word`, `prefix*`, `*suffix`,
  `*substring*`, or `prefix*suffix`.
  Lower-case letters are case insensitive,
  while upper-case letters are case sensitive.
  Restrict search to title or body via `title:...` or `body:...`
  (default is to search both).
  Negative match with minus sign
  (e.g., `-word` excludes documents with whole `word`).
  Search for a regular expression via `regex:...`.
  Use quotes (`'...'` or `"..."`) to search for phrases or `regex:"..."`
  to search for regular expressions with spaces in them; normally,
  spaces act as an AND query.
  Connect words/phrases with `|` to get an OR query instead.
  `tag:...` does an exact match for a specified tag; it can be negated.
  `is:root` matches root messages (tops of threads).
  `is:file` matches file messages (made via Attach).
  `is:deleted`, `is:published`, `is:private`, `is:minimized` match various
  states of messages.

* **User search**:
  find posts by a particular user by clicking on their username.
  Search for your own posts in a group by clicking the "My Posts" button.

* **Statistics** about user's and all posts within a group, by day, week
  (with configurable week start), month, year, or hour within a day.
  Your own statistics are available via the Statistics button on the group
  page, while other users' stats are available from their user page.

* **Permanent URLs** for all messages, groups, etc., for easy emailing etc.
  (but other than group name, not revealing, so only those with permission
  can open).  Links to other messages via specical `coauthor:xxx` syntax.
  Drag messages (via their arrow icon) into other messages to make such links.

* **Files** (another type of message) can be attached to other messages, as
  another type of reply.  You can click on the Attach button to select a file
  to attach, or drag the file from the operating system onto the Attach
  button.  Similarly, files can be modified by clicking the Replace File
  button or dragging a file onto that button.
  File messages can have title and body too; title defaults to the filename.
  Image/video files (including PNG, JPEG, SVG, MP4) are displayed inline.
  Images automatically detect EXIF orientation, and can be further rotated by
  multiples of 90 degrees in edit mode.
  PDF files are rendered using [pdf.js](https://mozilla.github.io/pdf.js/),
  only when visible on screen, and displayed inline with page-turning buttons.

* Messages can start/be marked **Unpublished** (not yet finished) or
  **Deleted** (mistake / no longer useful).
  In either state, the message is hidden from people who are not authors
  (an *author* is someone who has edited the message), @-mentioned
  (via `@username`), or superusers.
  The default published state is initially true (so everyone sees the new
  message and live updates immediately), but can vary by user (e.g., if they
  are "shy" and only want to post finished thoughts).

* Threads can be marked as allowing **public** replies only (the default, for
  maximum collaboration), **private** replies only (useful for solved
  problems/puzzles, to prevent accidentally spoiling the fun), or
  **public and private** replies (useful for feedback on lectures, for example,
  which can have varying relevance to the entire group).  Replies to replies
  inherit the public/private state of their parent.  Superusers can
  see all the messages and change them between public and private.
  Private messages can @-mention another user (via `@username` in the body)
  to allow them to see and jointly edit the message.

* **Email notifications** for subscribed threads, clustering together all
  updates since the last email, with a maximum lag a specified number of
  hours or minutes (default 1 hour).
  Each user can specify in Settings whether they are, by default, subscribed
  to all threads or none, both globally and local to each group.
  Either way, the default can be overridden in the group view using the
  checkbox on the right (checked means "subscribed").
  Users can choose in Settings whether to receive notifications
  about their own edits.

* **Time travel**: You can drag through history and see past versions.
  In general, there should be good, automatic history tracking of everything.

* **Permissions** can be specified for each user at the group level
  (typical case --- user can access the entire group of messages),
  at the thread level (user can access only certain threads within group),
  or at the global level: just click "Users" in the appropriate view.
  Levels of access:

     * read: see the group and read the messages (otherwise invisible)
     * post: create new messages, replies, etc. in the group
     * edit: modify other people's messages
     * super: somewhat dangerous "super" operations like history-destroying
       superdelete, history-creating import, and the ability to see other users'
       deleted messages
     * admin: administer over other users, in particular setting permissions

* **Superuser operations** (only for superusers):
  * Import from LaTeX document with figures attached as a ZIP file
  * Import from osqa's XML dump, including old edit history
  * Superdelete (permanently destroying a message including its history)
  * Setting the default sort for a group

## User Tips ##

* On Android, the
  [Chrome browser](https://play.google.com/store/apps/details?id=com.android.chrome&hl=en)
  with [SwiftKey keyboard](https://play.google.com/store/apps/details?id=com.touchtype.swiftkey)
  seems to work best for editing messages in Coauthor.
  (Firefox and Gboard have cursor positioning issues.)
* LaTeX mode supports LaTeX accents (like `\'e`), but other modes do not.  To
  easily type accented characters (e.g., on Windows where this is not easy), try
  [this Chrome extension](https://chrome.google.com/webstore/detail/fastaccent/gkadokkbkifbfpiljldcnnpkebpannhb/related?hl=en-GB)
  or
  [this Firefox extension](https://addons.mozilla.org/en-us/firefox/addon/easyaccent/).
* Conversely, if you're on modern MacOS, holding down letter keys will bring
  up an accent tool instead of repeating the key.  If you'd rather repeat the
  key (e.g. for Vim mode),
  [follow these instructions](http://www.idownloadblog.com/2015/01/14/how-to-enable-key-repeats-on-your-mac/):
  `defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false`
  then restart your web browser.

## [Installation](INSTALL.md) ##

See [detailed installation instructions](INSTALL.md).
