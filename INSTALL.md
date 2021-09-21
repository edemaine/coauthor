# Installing a Coauthor Server

## Test Server

Here is how to get a **local test server** running:

1. **[Install Meteor](https://docs.meteor.com/install.html):**
   `npm install -g meteor` or `sudo npm install -g meteor --unsafe-perm`.
   Prefix with `arch -x86_64` on Apple M1.
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
machine via [meteor-up](https://github.com/kadirahq/meteor-up).
Installation instructions:

1. Install Meteor and download Coauthor as above.
2. Install `mup` via `npm install -g mup`
   (after installing [Node](https://nodejs.org/en/) and thus NPM).
3. Edit `.deploy/mup.js` to match your configuration:
   * `servers.one` holds the information for accessing the server:
     * `host` is the hostname or IP address of the server.
     * `username` is the username of a root-level account on the server
       that will be used to install software and run Coauthor.
     * `pem` is the path on the local machine to an SSH private key
       that enables access to the server host and username.
   * `meteor.path` should point to the base directory on the local machine
     that contains Coauthor (the directory containing `.deploy`).
   * `meteor.proxy.ssl` specifies how to enable SSL encryption (https).
     The easy way is to use [Let's Encrypt](https://letsencrypt.org/)
     by specifying your email address in `letsEncryptEmail`.  Alternatively,
     if you have your own SSL certificate, specify that in `crt` and `key`.
     Or disable SSL altogether by removing `forceSSL: true` or the entire
     `meteor.proxy.ssl` block.
   * `meteor.env` sets environment variables:
     * `ROOT_URL` must be the root URL for your public web server.
     * For Coauthor to send email notifications, `MAIL_URL` needs to specify
       an SMTP server.  See
       [`MAIL_URL` configuration](https://docs.meteor.com/api/email.html).
       To run a local SMTP server, [see below](#email), and use e.g.
       `smtp://yourhostname.org:25/`.
       [`smtp://localhost:25/` may not work because of mup's use of docker.]
     * If you want the "From" address in email notifications to be something
       other than coauthor@*deployed-host-name*, set the `MAIL_FROM` variable.
     * If you're upgrading from an older Coauthor, don't set the
       `COAUTHOR_SKIP_UPGRADE_DB` variable for the first deploy.
4. Edit `settings.json` to set the server's
   [timezone](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)
   (used as the default email notification timezone for all users).
5. `cd .deploy`
6. `mup setup` to install all necessary software on the server
7. `mup deploy` each time you want to deploy code to server
   (initially and after each `git pull`)
8. If you proxy the resulting server from another web server,
   you'll probably want to `meteor remove force-ssl` to remove the automatic
   redirection from `http` to `https`.

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

## Application Performance Management (APM)

To monitor server performance, you can use one of the following:
* [Monti APM](https://montiapm.com/)
  (no setup required, free for 8-hour retention); or
* deploy your own
  [open-source Kadira server](https://github.com/kadira-open/kadira-server).
  To get this running (on a different machine), I recommend
  [kadira-compose](https://github.com/edemaine/kadira-compose).

After creating an application on one of the servers above,
create `server/kadira.coffee` with the following lines:

```coffee
Kadira.connect 'xxxxxxxxxxxxxxxxx', 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
  endpoint: 'https://your-kadira-server:22022'  # omit this line if using Monti
```

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
