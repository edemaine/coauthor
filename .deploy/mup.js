module.exports = {
  servers: {
    one: {
      host: 'coauthor.csail.mit.edu',
      username: 'ubuntu',
      pem: "/afs/csail/u/e/edemaine/.ssh/private/id_rsa"
      // pem:
      // password:
      // or leave blank for authenticate from ssh-agent
    }
  },

  // Meteor server
  meteor: {
    name: 'coauthor',
    path: '/afs/csail/u/e/edemaine/Projects/coauthor',
    servers: {
      one: {}
    },
    docker: {
      image: 'abernix/meteord:node-12-base',
      stopAppDuringPrepareBundle: false
    },
    buildOptions: {
      serverOnly: true,
      buildLocation: '/scratch/coauthor-build'
    },
    env: {
      // Comment this out to upgrade the database (for Coauthor upgrades).
      // This can take a while on startup, so be sure to also increase
      // deployCheckWaitTime below.
      COAUTHOR_SKIP_UPGRADE_DB: '1',
      // Set to your public-facing URL
      ROOT_URL: 'https://coauthor.csail.mit.edu',
      // Set to your SMTP server, to enable Coauthor email notifications.
      // Comment out this line to turn off email notifications.
      MAIL_URL: 'smtp://coauthor.csail.mit.edu:25?ignoreTLS=true',
      // Default From address for mail notifications is
      // coauthor@deployed-host-name; set this to override:
      //MAIL_FROM: 'coauthor@coauthor.csail.mit.edu',
      // If you don't use MUP's MongoDB server, set this to your server:
      MONGO_URL: 'mongodb://mongodb/meteor',
      // You shouldn't need to change this:
      MONGO_OPLOG_URL: 'mongodb://mongodb/local',
      // Set to fill available RAM:
      NODE_OPTIONS: '--trace-warnings --max-old-space-size=8192'
    },
    // If you're upgrading the database, you probably need to increase this:
    deployCheckWaitTime: 200,
    //deployCheckWaitTime: 2000,
    /* Old mup-frontend-server configuration:
    ssl: {
      // pem: '../coauthor_csail_mit_edu.ssl/coauthor_csail_mit_edu.pem'
      crt: '../../coauthor_csail_mit_edu.ssl/coauthor_csail_mit_edu.pem',
      key: '../../coauthor_csail_mit_edu.ssl/coauthor_csail_mit_edu.key',
      port: 443
    },
    nginx: {
      clientUploadLimit: '0', // disable upload limit
    },
    */
  },

  // Mongo server
  mongo: {
    // Mongo 4 has the advantage of free cloud monitoring
    // [https://docs.mongodb.com/manual/administration/monitoring/].
    // But you can also run an old version such as the default '3.4.1'.
    version: '4.4.4',
    oplog: true,
    port: 27017,
    servers: {
      one: {},
    },
  },

  // Reverse proxy for SSL
  proxy: {
    domains: 'coauthor.csail.mit.edu',
    ssl: {
      // pem: '../coauthor_csail_mit_edu.ssl/coauthor_csail_mit_edu.pem'
      crt: '../../coauthor_csail_mit_edu.ssl/coauthor_csail_mit_edu.pem',
      key: '../../coauthor_csail_mit_edu.ssl/coauthor_csail_mit_edu.key',
      forceSSL: true,
    },
    clientUploadLimit: '0', // disable upload limit
    nginxServerConfig: '../.proxy.config',
  },

  // Run 'npm install' before deploying, to ensure packages are up-to-date
  hooks: {
    'pre.deploy': {
      localCommand: 'npm install'
    }
  },
};
