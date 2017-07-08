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

  meteor: {
    name: 'coauthor',
    path: '/afs/csail/u/e/edemaine/Projects/coauthor',
    servers: {
      one: {}
    },
    dockerImage: 'abernix/meteord:base', 
    docker: {
      image: 'abernix/meteord:base', 
    },
    buildOptions: {
      serverOnly: true,
      buildLocation: '/scratch/coauthor-build'
    },
    env: {
      ROOT_URL: 'https://coauthor.csail.mit.edu',
      PORT: 80,
      MAIL_URL: 'smtp://coauthor.csail.mit.edu:25',
      //MAIL_FROM: 'coauthor@coauthor.csail.mit.edu',
      MONGO_URL: 'mongodb://localhost/meteor'
    },
    ssl: {
      // pem: '../coauthor_csail_mit_edu.ssl/coauthor_csail_mit_edu.pem'
      crt: '../coauthor_csail_mit_edu.ssl/coauthor_csail_mit_edu.pem',
      key: '../coauthor_csail_mit_edu.ssl/coauthor_csail_mit_edu.key',
      port: 443
    },
    deployCheckWaitTime: 150
  },

  mongo: {
    oplog: true,
    port: 27017,
    servers: {
      one: {},
    },
  },
};
