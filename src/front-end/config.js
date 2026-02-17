(function (){
  'use strict';

  var session      = require("express-session"),
      RedisStore   = require('connect-redis').default,
      redis        = require('redis')

  var redisClient = null;
  var redisStore = null;

  // Only create Redis client if SESSION_REDIS is set
  if (process.env.SESSION_REDIS) {
    redisClient = redis.createClient({
      socket: {
        host: process.env.REDIS_HOST || "session-db",
        port: process.env.REDIS_PORT || 6379
      }
    });

    redisClient.on('error', function(err) {
      console.log('Redis Client Error', err);
    });

    redisClient.connect().catch(function(err) {
      console.log('Redis connection error:', err.message);
    });

    redisStore = new RedisStore({
      client: redisClient,
      prefix: 'md:'
    });
  }

  module.exports = {
    session: {
      name: 'md.sid',
      secret: 'sooper secret',
      resave: false,
      saveUninitialized: true
    },

    session_redis: {
      store: redisStore,
      name: 'md.sid',
      secret: 'sooper secret',
      resave: false,
      saveUninitialized: true
    }
  };
}());
