(function (){
  'use strict';

  var util = require('util');

  function normalizeBaseUrl(url) {
    return url.replace(/\/+$/, "");
  }

  var domain = "";
  process.argv.forEach(function (val, index, array) {
    var arg = val.split("=");
    if (arg.length > 1) {
      if (arg[0] == "--domain") {
        domain = "." + arg[1];
        console.log("Setting domain to:", domain);
      }
    }
  });

  var defaultCartsHost = util.format("carts%s", domain);
  var cartsPortSuffix = process.env.CARTS_PORT ? util.format(":%s", process.env.CARTS_PORT) : "";
  var cartsBaseUrl = process.env.CARTS_BASE_URL || util.format("http://%s%s", defaultCartsHost, cartsPortSuffix);
  cartsBaseUrl = normalizeBaseUrl(cartsBaseUrl);

  module.exports = {
    catalogueUrl:  util.format("http://catalogue%s", domain),
    tagsUrl:       util.format("http://catalogue%s/tags", domain),
    cartsUrl:      util.format("%s/carts", cartsBaseUrl),
    ordersUrl:     util.format("http://orders%s", domain),
    customersUrl:  util.format("http://user%s/customers", domain),
    addressUrl:    util.format("http://user%s/addresses", domain),
    cardsUrl:      util.format("http://user%s/cards", domain),
    loginUrl:      util.format("http://user%s/login", domain),
    registerUrl:   util.format("http://user%s/register", domain),
  };
}());
