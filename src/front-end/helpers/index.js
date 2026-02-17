(function (){
  'use strict';

  var axios = require("axios");
  var helpers = {};

  /* Public: errorHandler is a middleware that handles your errors */
  helpers.errorHandler = function(err, req, res, next) {
    var ret = {
      message: err.message,
      error:   err
    };
    if (!res.headersSent) {
      res.status(err.status || 500).send(ret);
    }
  };

  // Fixed: removed 'err' param (was making Express treat this as error handler)
  // Fixed: changed res.session to req.session
  // Fixed: added next() so request continues
  helpers.sessionMiddleware = function(req, res, next) {
    if(!req.cookies.logged_in) {
      if (req.session) {
        req.session.customerId = null;
      }
    }
    next();
  };

  /* Responds with the given body and status 200 OK  */
  helpers.respondSuccessBody = function(res, body) {
    helpers.respondStatusBody(res, 200, body);
  }

  /* Public: responds with the given body and status */
  helpers.respondStatusBody = function(res, statusCode, body) {
    if (res.headersSent) return;
    res.writeHead(statusCode);
    if (typeof body === 'object') {
      res.write(JSON.stringify(body));
    } else {
      res.write(body);
    }
    res.end();
  }

  /* Responds with the given statusCode */
  helpers.respondStatus = function(res, statusCode) {
    if (res.headersSent) return;
    res.writeHead(statusCode);
    res.end();
  }

  /* Rewrites and redirects any url that doesn't end with a slash. */
  helpers.rewriteSlash = function(req, res, next) {
   if(req.url.substr(-1) == '/' && req.url.length > 1)
       res.redirect(301, req.url.slice(0, -1));
   else
       next();
  }

  /* Public: performs an HTTP GET request to the given URL */
  helpers.simpleHttpRequest = function(url, res, next) {
    axios.get(url)
      .then(function(response) {
        helpers.respondSuccessBody(res, response.data);
      })
      .catch(function(error) {
        return next(error);
      });
  }

  /* TODO: Add documentation */
  helpers.getCustomerId = function(req, env) {
    var logged_in = req.cookies.logged_in;

    if (env == "development" && req.query.custId != null) {
      return req.query.custId;
    }

    if (!logged_in) {
      if (!req.session.id) {
        throw new Error("User not logged in.");
      }
      return req.session.id;
    }

    return req.session.customerId;
  }
  module.exports = helpers;
}());
