module.exports = {
  servers: {
    one: {
      host: 'coauthor.csail.mit.edu',
      username: 'ubuntu',
      pem: "/afs/csail/u/e/edemaine/.ssh/private/id_dsa"
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
      image: 'abernix/meteord:node-8.4.0-base', 
      stopAppDuringPrepareBundle: false
    },
    buildOptions: {
      serverOnly: true,
      buildLocation: '/scratch/coauthor-build'
    },
    env: {
      ROOT_URL: 'https://coauthor.csail.mit.edu',
      MAIL_URL: 'smtp://coauthor.csail.mit.edu:25?ignoreTLS=true',
      //MAIL_FROM: 'coauthor@coauthor.csail.mit.edu',
      MONGO_URL: 'mongodb://mongodb/meteor',
      MONGO_OPLOG_URL: 'mongodb://mongodb/local',
      NODE_OPTIONS: '--trace-warnings'
    },
    deployCheckWaitTime: 200,
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
