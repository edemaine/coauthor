# Coauthor #

**Coauthor** is a tool for group collaboration, discussion, keeping track of
notes/results of meetings, etc.  Its primary goal is to ease multiauthor
collaboration on unsolved problems in theoretical computer science, so
e.g. you'll find LaTeX math support; hopefully it will have applications
in other fields too.

## Features So Far ##

* **Live updates**/redraw of everything, thanks to
  [Meteor](https://www.meteor.com/).  No more hitting "reload".
  If you're looking at a problem and someone posts/edits something,
  you see it as quickly as they see their preview (roughly 1-second delay).

* **Real-time editing** of messages in the style of EtherPad (Operational
  Transforms), if people feel like editing together
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
  [this list of supported functions](https://github.com/Khan/KaTeX/wiki/Function-Support-in-KaTeX).

  * [Github-style Markdown](https://guides.github.com/features/mastering-markdown/)
    (default), e.g., `*italic*`, `**bold**`, `~~strikethrough~~`,
    `# Heading`, `## Subheading`, \`code\`, `> Block quote`,
    <code>\`\`\`multiple lines of code\`\`\`</code>,
    links via `[text](url)`, images via `![caption](url)`,
    lists via `*` or `1.`, tables, etc.
  * LaTeX, limited.  Beyond extensive math mode support (see below),
    the following features are supported in text mode; feel free to ask
    for more.  `%...`, `\def\macro{...}`, `\let\macro=\mac`, `\protect`,
    `\textbf`, `\textit`, `\textsf`, `\emph`, `\textsc`, `\underline`,
    `\textcolor{color}{text}`, `\colorbox{backcolor}{text}`,
    `\url`, `\href{url}{text}`, `\pdftooltip{hovertext}{text}`,
    `\raisebox{amount}{text}`, `\par`,
    `\BY{...}`, `\YEAR{...}`,
    `\chapter`, `\section`, `\subsection`, `\subsubsection`, `\footnote`,
    `\includegraphics[width/height]{url}`, `\"`, `\'`, ```\` ```,
    `\^`, `\~`, `\=`, `\c`, `\v`, `\u`, `\H`, ``` `` ```, `''`,
    `\&`, `\$`, `\{`, `\}`, `~`, `--`, `---`, `\\`, `\item`,
    `\begin/\end` for environments `verbatim`, `enumerate`, `itemize`,
    `equation`, `eqnarray`, `align`,
    `problem`, `theorem`, `conjecture`, `lemma`, `corollary`, `fact`,
    `observation`, `proposition`, `claim`, `proof`.
  * HTML, sanitized.  The following tags are allowed; feel free to ask for
    more.  `<h1>`, `<h2>`, `<h3>`, `<h4>`, `<h5>`, `<h6>`,
    `<blockquote>`, `<p>`, `<div>`, `<span>`,
    `<a href/name/target>`, `<ul>`, `<ol start>`, `<nl>`, `<li>`, `<b>`,
    `<strong>`, `<i>`, `<em>`, `<u>`, `<s>`, `<strike>`, `<del>`, `<code>`,
    `<hr>`, `<br>`, `<table>`, `<thead>`, `<caption>`,
    `<tbody>`, `<tr>`, `<th>`, `<td>`, `<pre>`,
    `<img src/alt/width/height>`, `<video controls>`, `<source src>`
    attributes `title/style/class/aria-*`.

* [CodeMirror editor](http://codemirror.net/) supports syntax highlighting,
  block folding, bracket matching, line numbering, light and dark themes,
  [spell checking](https://github.com/NextStepWebs/codemirror-spell-checker),
  "regular" keybindings as well as Vim and Emacs keybindings
  (if you've ever needed rectangular selection for e.g. ASCII art).

* Organization by **groups** (intended to correspond to groups of people who
  meet).  Users can have permission to see and/or post within each
  group, or at a global level (mainly intended for admins).
  Admins can edit the permissions of other users via the "Users" button.

* **Sorting** of threads within a group by title, creator, creation date,
  last update, number of posts, or whether subscribed (by clicking on the
  corresponding column, once for default sort order and again for
  opposite sort order).  Intelligent handling of numbers while sorting,
  e.g. "9." comes before "10.".

* "**Live Feed**" to watch messages as they get changed/posted.  Useful for
  projecting the latest activity onto a big screen while a group is gathered
  and some are maybe editing.

* "**Catchup on Recent Posts**" to see all messages since a particular date/time
  (including relative specifications like "1 week" or "12 hours").
  Useful for progress reports since the last meeting.

* **Threaded** message organization, with arbitrary tree structure (root
  messages, replies with arbitrary depth).  You can focus on the subthread
  rooted at any message (click on the arrow), or fold away the contents of a
  subthread to focus on the rest.
  (Currently the folds are not preserved across sessions / rerenders.)

* **Dragging** messages to change the parentage/hierarchy, or move their
  position within their parent.  Dragging directly onto a message makes
  the dragged message the last child, while dragging onto the slot before
  a message makes the dragged message the immediately preceding sibling.
  Dialog confirms move.

* **Tags**: attached an arbitrary set of strings to a message.  Find other
  messages with the same tag by clicking on a tag.

* **Search** for posts by a particular user by clicking on their username.
  Search for your own posts in a group by clicking the "My Posts" button.

* **Permanent URLs** for all messages, groups, etc., for easy emailing etc.
  (but other than group name, not revealing, so only those with permission
  can open).  Links to other messages via specical coauthor:xxx syntax.
  Drag messages (via their arrow icon) into other messages to make such links.

* **Files** (another type of message) can be attached to other messages, as
  another type of reply.  File messages can have title and body too; title
  defaults to the filename.  Files can be replaced.  Image/video files
  (including PNG, JPEG, SVG, MP4) are displayed inline.  (In the future,
  they and other visual file types such as PDF will be rendered by some
  kind of thumbnails.)

* Messages can start **Unpublished**, or after publication, **Deleted**;
  in either state, the message is hidden from non-authors.  (An *author* is
  someone who has edited the message, or who is @-mentioned in the body.)
  The default published state is initially true (so everyone sees the new
  message and live updates immediately), but can vary by user (e.g., if they
  are "shy" and only want to post finished thoughts).

* Threads can be marked as allowing **public** replies only (the default, for
  maximum collaboration), **private** replies only (useful for solved
  problems/puzzles, to prevent accidentally spoiling of the fun), or
  **public and private** replies (useful for feedback on lectures, for example,
  which can have varying relevance to the entire group).  Replies to replies
  inherit the public/private state of their parent.  Superusers can
  see all the messages and change them between public and private.
  Private messages can @-mention another user (via `@username` in the body)
  to allow them to see and jointly edit the message.

* **Email notifications** for subscribed threads, clustering together all
  updates since the last email, with a maximum of 1 hour lag.
  Each user can specify in Settings whether they are, by default, subscribed
  to all threads or none.  Either way, the default can be overridden in the
  group view using the checkbox on the right (checked means "subscribed").
  Users can choose in Settings whether to receive notifications about their
  own edits.

* **Time travel**: You can drag through history and see past versions.
  In general, there should be good, automatic history tracking of everything,
  including a not-yet-visible reparenting feature.

* **Superuser operations** (only for superusers):
  * Import from LaTeX document with figures attached as a ZIP file
  * Import from osqa's XML dump, including old edit history
  * Superdelete (permanently destroying a message including its history)
  * Setting the default sort for a group

## User Tips ##

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

## Installation and Permissions ##

Here is how to get a local test server running:

1. `curl https://install.meteor.com/ | sh` on UNIX, or use the
   [Windows installer](https://www.meteor.com/install)
2. `git clone https://github.com/edemaine/coauthor.git`
3. `cd coauthor`
4. `meteor npm install`
5. `meteor`
6. Open the website [http://localhost:3000/](http://localhost:3000/)
7. Create an account
8. `meteor mongo`
9. Give your account permissions as follows:

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

To deploy to a public server, we recommend
[meteor-up](https://github.com/kadirahq/meteor-up).

1. Edit `.deploy/mup.js` to point to your SSH key (for accessing the server),
   your SSL certificate (for an https server), and your SMTP server
   (see below).
2. `mup setup` to install all necessary software on the server
3. `mup deploy` each time you want to deploy code to server
   (initially and after each `git pull`)

You'll also need an SMTP server to send email notifications.
In Postfix, modify the `/etc/postfix/main.cf` configuration as follows
(substituting your own hostname):

 * Set `myhostname = yourhostname.com`
 * Add `, $myhostname` to `mydestination`
 * Add ` 172.17.0.0/16` to `mynetworks`:

   `mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 172.17.0.0/16`

If you want `coauthor@yourhostname.com` to receive email,
add an alias like `coauthor: edemaine@mit.edu` to `/etc/aliases`
and then run `sudo newaliases`.

If you want to use [Kadira](https://kadira.io/) to monitor the performance,
errors, etc., the package is already installed; just add credentials to a
`server/kadira.js` file.
