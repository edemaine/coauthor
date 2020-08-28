# Installing a Coauthor Server

## Test Server

Here is how to get a **local test server** running:

1. **[Install Meteor](https://www.meteor.com/install):**
   `curl https://install.meteor.com/ | sh` on UNIX,
   `choco install meteor` on Windows (in administrator command prompt
   after [installing Chocolatey](https://chocolatey.org/install))
2. **Download Coauthor:** `git clone https://github.com/edemaine/coauthor.git`
3. **Run meteor:**
   * `cd coauthor`
   * `meteor npm install`
   * `meteor`
4. **Make a superuser account:**
   * Open the website [http://localhost:3000/](http://localhost:3000/)
   * Create an account
   * `meteor mongo`
   * Give your account permissions as follows:

     ```
     meteor:PRIMARY> db.users.update({username: 'edemaine'}, {$set: {'roles.*': ['read', 'post', 'edit', 'super', 'admin']}})
     WriteResult({ "nMatched" : 1, "nUpserted" : 0, "nModified" : 1 })
     ```

     `*` means all groups, so this user gets all permissions globally.

Even a test server will be accessible from the rest of the Internet.  However,
many features (including editing messages) will work only if you set the
`ROOT_URL` environment variable to `http://your.host.name:3000`
before running `meteor` in Step 3.

## Public Server

To deploy to a **public server**, we recommend deploying from a development
machine via [Meteor Up](https://github.com/kadirahq/meteor-up).  This software
allows you to build the code on your own machine and deploy it to a remote
server with a minimum of hassle.  In particular, it will set up Docker
containerization automatically, as well as an HTTPS proxy.

### Setting Up a Server

1. Coauthor requires a server to run.  If you don't have one, you can get one
   easily from [DigitalOcean](https://www.digitalocean.com/).  Their most
   basic plan costs US$5/mo and works fine for small classes.
2. Coauthor needs a domain name to send email from.  You can buy them cheaply
   online from any domain name registrar.  Your hosting provider will tell you
   how to connect your domain name to your server using DNS.  Make sure you
   set up both forward and reverse DNS: the first connects your domain name to
   your server and the second lets your server, and other devices that only know
   your server's IP address, figure out its domain name.  Again, your hosting
   provider will tell you how to do this.
3. You may or may not be given an HTTPS or SSL certificate.  If you are, hang
   on to it.  If not, don't worry.
4. Once your server is up, running, and paid for, you don't have to touch it for
   a while.  The main steps in publicly deploying Coauthor are all done on your
   own computer.  Make sure you know how to SSH into your server, though.  Your
   hosting provider will tell you how.

### On Your Local Machine

1. (Optional but recommended) Set up a virtual machine.  This process requires
   installing a significant amount of software that could otherwise pollute
   your environment.  You can use [Multipass](https://multipass.run) for this.
   We recommmend no less than 4GB RAM and 10GB hard disk space.  The Multipass
   defaults are too stingy.
2. (In your virtual machine if you have one) Install
   [Node Version Manager](https://github.com/nvm-sh/nvm), not forgetting to
   restart your terminal, and use it to install the latest long-term support
   version of Node.js.  At the time of writing, that would be `lts/erbium`.
3. Install [Meteor](https://www.meteor.com/install).
4. Install Meteor Up, or `mup`, via `npm install -g mup`.
5. Set up an SSH key file that will allow you to access the server.  If you're
   on Linux, which you will be if you use Multipass, you can follow
   [this tutorial](https://www.digitalocean.com/community/tutorials/how-to-set-up-ssh-keys--2).
6. Download Coauthor: `git clone https://github.com/edemaine/coauthor.git`
7. Enter the `.deploy` folder: `cd coauthor/.deploy`.  This folder contains
   a file called `mup.js` which contains the settings for deployment to the
   server.
   1. In the `servers` section, for server `one`, set `host` to the address
      you use to SSH into your server, `username` to the username you use, and
      `pem` to the path to your SSH key file.
   2. Set `path` to the path to where you saved your copy of the Coauthor
      GitHub project.
   3. In the `buildOptions` section, the `buildLocation` parameter gives the
      path to a folder which Meteor Up will create and where it will store
      intermediate files during the build process.  Set this to a path where you
      know you can create folders without running into permission issues.
   4. In the `env` section, in `ROOT_URL` and `MAIL_URL`, replace
      `coauthor.csail.mit.edu` with your domain name.
   5. In the `proxy` section, in `ssl`, you have two options.  If you have an
      SSL certificate already, set the `crt` and `key` parameters to the paths
      to your `pem` and `key` files respectively.  (This may involve uploading
      these two files to your virtual machine.)  If not, delete both those lines
      and replace them with `letsEncryptEmail: 'your@email.com',`, filling in
      your email and not forgetting the comma at the end.  This will cause
      Meteor Up to use [Let's Encrypt](https://letsencrypt.org/) to automatically
      get you a free, secure SSL certificate.
8. Still in the `.deploy` folder, run `mup setup` to prepare the remote
   server, and `mup deploy` to push your code.  This will take some time.
9. Remember to shut down your virtual machine if you're using one.

### On the Server

1. Install and configure a mail server.  If you're on a Linux server,
   which, if you're using DigitalOcean, you probably are, you can use
   Postfix, which you can configure following
   [this tutorial](https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-postfix-on-ubuntu-20-04),
   **except** that, when prompted to list local networks, you should
   add `172.17.0.0/16` after the default list.  The section below on email
   goes into this in more detail, but if you follow this step and your DNS
   is properly configured you should, usually, be fine.
2. Coauthor should now be running on the server.  Open it up in a browser
   and create an account for yourself.
3. You now need to access the database on the server and make yourself an
   admin, so SSH into the server.  Since Meteor Up set up its database to
   run in a Docker container, you should run `docker exec -it mongodb mongo coauthor`
   to get a MongoDB shell.
4. In this shell, run `db.users.update({username: '<username>'}, {$set: {'roles.*': ['read', 'post', 'edit', 'super', 'admin']}})`,
   replacing `<username>` with the username you created for yourself.  You
   should see `WriteResult({ "nMatched" : 1, "nUpserted" : 0, "nModified" : 1 })`.
   Press <kbd>Ctrl</kbd>+<kbd>D</kbd> to exit the MongoDB shell.  Log off.
   You're done!

### Email

You'll also need an SMTP server to send email notifications.
Make sure that your server has both **DNS** (hostname to IP mapping) *and*
**reverse DNS (PTR)** (IP to hostname mapping), and that these point to
each other.  Otherwise, many mail servers (such as
[MIT's](http://kb.mit.edu/confluence/display/istcontrib/554+5.7.1+Delivery+not+authorized))
will not accept email sent by the server.

If you're using Postfix, modify the `/etc/postfix/main.cf` configuration as
follows (substituting your own hostname):

 * Set `myhostname = yourhostname.com`
 * Add `, $myhostname` to `mydestination`
 * Add ` 172.17.0.0/16` to `mynetworks`:

   `mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 172.17.0.0/16`

The first two of these modifications are done automatically for you if you
select "Internet site" when setting up Postfix.

Set the `MAIL_FROM` environment variable (in `.deploy/mup.js`) to the
return email address (typically `coauthor@yourhostname.com`) you'd like
notifications sent from.

If you want `coauthor@yourhostname.com` to receive email,
add an alias like `coauthor: edemaine@mit.edu` to `/etc/aliases`
and then run `sudo newaliases`.

### Disabling Email

If you do not want Coauthor to even ask users for their email address when
signing up (for example, to [protect minors](https://minors.mit.edu/),
modify `settings.json` to add the following setting:

```json
  "public": {
    "coauthor": {
      "emailless": true
    }
  },
```

If you're running a test server, be sure to run it via
`meteor --settings settings.json`.

Of course, email notifications generally won't work in this setup.
But global superusers can still edit and enter their email address under
Settings (if they Become Superuser), so they could still sign up for
email notifications.

## Kadira

To monitor server performance, you can install an
[open-source Kadira server](https://github.com/kadira-open/kadira-server),
and either add the `Kadira.connect` call to `server/kadira.coffee` or
set the `KADIRA_APP_ID` and `KADIRA_APP_SECRET` environment variables in
`.deploy/mup.js` (but don't publish these credentials).

To get open-source Kadira running (on a different server), I recommend
[kadira-compose](https://github.com/edemaine/kadira-compose).

## MongoDB

All of Coauthor's data (including messages, history, and file uploads)
is stored in the Mongo database (which is part of Meteor).
You probably want to do regular (e.g. daily) dump backups.
There's a script in `.backup` that I use to dump the database,
copy to the development machine, and upload to Dropbox or other cloud storage
via [rclone](https://rclone.org/).

`mup`'s MongoDB stores data in `/var/lib/mongodb`.  MongoDB prefers an XFS
filesystem, so you might want to
[create an XFS filesystem](http://ask.xmodulo.com/create-mount-xfs-file-system-linux.html)
and mount or link it there.
(For example, I have mounted an XFS volume at `/data` and linked via
`ln -s /data/mongodb /var/lib/mongodb`).

`mup` also, by default, makes the MongoDB accessible to any user on the
deployed machine.  This is a security hole: make sure that there aren't any
user accounts on the deployed machine.
But it is also useful for manual database inspection and/or manipulation.
[Install MongoDB client
tools](https://docs.mongodb.com/manual/administration/install-community/),
run `mongo coauthor` (or `mongo` then `use coauthor`) and you can directly
query or update the collections.  (Start with `show collections`, then
e.g. `db.messages.find()`.)
On a test server, you can run `meteor mongo` to get the same interface.

## Android app

Instructions for building the Coauthor Android app
(not yet functional):

0. Install [Android Studio](https://developer.android.com/studio/);
   add `gradle/gradle-N.N/bin`, `jre/bin`,
   `AppData/local/android/sdk/build-tools/26.0.2` to PATH
1. `keytool -genkey -alias coauthor -keyalg RSA -keysize 2048 -validity 10000`
   (if you don't already have a key for the app)
2. `meteor build ../build --server=https://coauthor.csail.mit.edu`
3. `cd ../build/android`
4. `jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 release-unsigned.apk coauthor`
5. `zipalign -f 4 release-unsigned.apk coauthor.apk`

## bcrypt on Windows

To install `bcrypt` on Windows (to avoid warnings about it missing), install
[windows-build-tools](https://www.npmjs.com/package/windows-build-tools)
via `npm install --global --production windows-build-tools`, and
then run `meteor npm install bcrypt`.
