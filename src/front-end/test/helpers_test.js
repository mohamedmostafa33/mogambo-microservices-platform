(function (){
  'use strict';

  var express    = require("express")
    , axios      = require("axios")
    , bodyParser = require("body-parser")
    , http       = require("http")
    , chai       = require("chai")
    , chaiHttp   = require("chai-http")
    , sinon      = require("sinon")
    , expect     = chai.expect
    , helpers    = require("../helpers")
    , app

  describe("helpers", function() {
    before(function() {
      chai.use(chaiHttp);
    });

    beforeEach(function() {
      app = express();
      app.use(bodyParser.json());
    });

    describe("#errorHandler", function() {
      var message, code, error, res, resErr;

      beforeEach(function(done) {
        message      = "Something went terribly wrong";
        code         = 501;
        error        = new Error(message);
        error.status = code;

        app.use(function(_req, _res) {
          helpers.errorHandler(error, _req, _res);
        });

        chai.request(app).
          get("/").
          set("Content-Type", "application/json").
          end(function(_err, _res) {
            resErr = _err;
            res    = _res;
            done();
          });
      });

      describe("the rendered JSON", function() {
        it("includes an error message", function() {
          expect(res.body).to.include.keys("message");
          expect(res.body.message).to.equal(message);
        });

        it("includes an error object", function() {
          expect(res.body).to.include.keys("error");
          expect(res.body.error).to.be.an('object');
        });

        it("returns the right HTTP status code", function() {
          expect(res).to.have.status(501);
        });
      });

      describe("given the error has no status defined", function() {
        beforeEach(function() {
          delete error.status;
        });

        it("responds with HTTP status code 500", function(done) {
          chai.request(app).
            get("/").
            set("Content-Type", "application/json").
            end(function(err, res) {
              expect(res).to.have.status(500);
              done();
            });
        });
      });
    });

    describe("#respondSuccessBody", function() {
      it("renders the given body with status 200 OK", function(done) {
        app.use(function(req, res) {
          helpers.respondSuccessBody(res, "ayylmao");
        });

        chai.request(app).
          get("/").
          end(function(err, res) {
            expect(res).to.have.status(200);
            expect(res.text).to.equal("ayylmao");
            done();
          });
      });
    });

    describe("#respondStatusBody", function() {
      it("sets the proper status code & body", function(done) {
        app.use(function(req, res) {
          helpers.respondStatusBody(res, 201, "foo");
        });

        chai.request(app).
          get("/").
          end(function(err, res) {
            expect(res).to.have.status(201);
            expect(res.text).to.equal("foo");
            done();
          });
      });
    });

    describe("#respondStatus", function() {
      it("sets the proper status code", function(done) {
        app.use(function(req, res) {
          helpers.respondStatus(res, 404);
        });

        chai.request(app).
          get("/").
          end(function(err, res) {
            expect(res).to.have.status(404);
            expect(res.text).to.equal("");
            done();
          });
      });
    });

    describe("#simpleHttpRequest", function() {
      var res, resErr;

      it("performs a GET request to the given URL", function() {
        var url = "http://google.com";
        sinon.stub(axios, "get").callsFake(function(requestedUrl) {
          expect(requestedUrl).to.equal(url);
          return Promise.resolve({ data: "test" });
        });
        helpers.simpleHttpRequest(url, {}, function() {});
        axios.get.restore();
      });

      describe("given the external service responds with success", function() {
        beforeEach(function(done) {
          sinon.stub(axios, "get").callsFake(function(url) {
            return Promise.resolve({ data: "success" });
          });

          app.use(function(_req, _res) {
            helpers.simpleHttpRequest("http://api.example.org/users", _res, function(err) {
              if (err) {
                return done(err);
              }
            });
          });

          chai.
            request(app).
            get("/").
            end(function(_err, _res) {
              if (_err) return done(_err);
              resErr = _err;
              res    = _res;
              done();
            });
        });

        afterEach(function() {
          axios.get.restore();
        });

        it("yields the external service response to the response body", function() {
          expect(res.text).to.equal("success");
        });

        it("responds with success", function() {
          expect(res).to.have.status(200);
        });
      });

      describe("given the external service fails", function() {
        it("invokes the given callback with an error object", function(done) {
          var spy = sinon.spy();

          sinon.stub(axios, "get").callsFake(function(url) {
            return Promise.reject(new Error("Something went wrong"));
          });

          app.use(function(req, res) {
            helpers.simpleHttpRequest("http://example.org/fail", res, function(err) {
              expect(err).not.to.be.null;
              expect(err.message).to.equal("Something went wrong");
              axios.get.restore();
              done();
            });
          });

          chai.
            request(app).
            get("/").
            end();
        });
      });
    });

    describe("#getCustomerId", function() {
      describe("given the environment is development", function() {
        it("returns the customer id from the query string", function() {
          var req = {
            query: { custId: "123" },
            cookies: {},
            session: {}
          };
          var result = helpers.getCustomerId(req, "development");
          expect(result).to.equal("123");
        });
      });

      describe("given a customer id set in session", function() {
        it("returns the customer id from the session", function() {
          var req = {
            query: {},
            cookies: { logged_in: true },
            session: { customerId: "456" }
          };
          var result = helpers.getCustomerId(req, "production");
          expect(result).to.equal("456");
        });
      });

      describe("given no customer id set in the cookies", function() {
        describe("given no customer id set session", function() {
          it("throws a 'User not logged in' error", function() {
            var req = {
              query: {},
              cookies: {},
              session: {}
            };
            expect(function() {
              helpers.getCustomerId(req, "production");
            }).to.throw("User not logged in.");
          });
        });
      });
    });
  });
 }());
