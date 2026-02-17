(function (){
  'use strict';

  var express = require("express")
    , client  = require('prom-client')
    , app     = express()

  const metric = {
    http: {
      requests: {
        duration: new client.Histogram({
          name: 'request_duration_seconds',
          help: 'request duration in seconds',
          labelNames: ['service', 'method', 'route', 'status_code']
        }),
      }
    }
  }

  function s(start) {
    var diff = process.hrtime(start);
    return (diff[0] * 1e9 + diff[1]) / 1000000000;
  }

  function observe(method, path, statusCode, start) {
    var route = path.toLowerCase();
    if (route !== '/metrics' && route !== '/metrics/') {
        var duration = s(start);
        var method = method.toLowerCase();
        metric.http.requests.duration.labels('front-end', method, route, statusCode).observe(duration);
    }
  };

  function middleware(request, response, done) {
    var start = process.hrtime();

    response.on('finish', function() {
      observe(request.method, request.path, response.statusCode, start);
    });

    return done();
  };


  app.use(middleware);
  app.get("/metrics", function(req, res) {
      res.header("content-type", "text/plain");
      return res.end(client.register.metrics())
  });

  module.exports = app;
}());
