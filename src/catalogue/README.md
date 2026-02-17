[![Build Status](https://travis-ci.org/microservices-demo/catalogue.svg?branch=master)](https://travis-ci.org/microservices-demo/catalogue)
[![Coverage Status](https://coveralls.io/repos/github/microservices-demo/catalogue/badge.svg?branch=master)](https://coveralls.io/github/microservices-demo/catalogue?branch=master)
[![Go Report Card](https://goreportcard.com/badge/github.com/microservices-demo/catalogue)](https://goreportcard.com/report/github.com/microservices-demo/catalogue)
[![Microbadger](https://images.microbadger.com/badges/image/weaveworksdemos/catalogue.svg)](http://microbadger.com/images/weaveworksdemos/catalogue "Get your own image badge on microbadger.com")


# Catalogue
A microservices-demo service that provides catalogue/product information.
This service is built, tested and released by travis.

## Bugs, Feature Requests and Contributing
We'd love to see community contributions. We like to keep it simple and use Github issues to track bugs and feature requests and pull requests to manage contributions.


# Dev

Platform supported : Ubuntu 16.04

Following are the instructions to setup a dev environment for catalogue.

```
sudo su
apt-get update && apt-get install -yq curl git wget
cd /tmp

echo "I: Setting up path for go and gvt"
export GOPATH=/opt/go
export GOROOT=/usr/local/go
export PATH="/opt/go/bin:$PATH"

mkdir /opt/go

echo "I: Install go from source..."

wget -c https://storage.googleapis.com/golang/go1.8.1.linux-amd64.tar.gz
tar -xzf go1.8.1.linux-amd64.tar.gz -C /usr/local


echo "Validating..."
which go
go version

echo "Install gvt..."
go get -u github.com/FiloSottile/gvt
which gvt

echo "I: Setup the repo..."
mkdir -p /opt/go/src/github.com/microservices-demo
cd /go/src/github.com/microservices-demo
git clone https://github.com/udbc/catalogue.git


echo "I: Compile the code ..."
cd catalogue/
cp -r images /images
gvt restore
cd cmd/cataloguesvc/
CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o /app/main github.com/microservices-demo/catalogue/cmd/cataloguesvc

echo "I: Launch the app...."
# Make sure you have mysql connection configurations done before launching the app
#echo "172.20.0.2 catalogue-db" >> /etc/hosts

/app/main -port 7081
```

## Production Deployment

### Create DB and load the schema

Install mysql and codereate a  database

e.g.
```
dbname: catalogue
user: devops
password: GKkdw72Jil0ld

```

Upload the schema to database created above.

path to schema :  **data/dump.sql**

### Deploy static  assets

  * Fetch the latest [release artifact from this URL](https://github.com/udbc/catalogue/releases)
e.g.
```
wget -c https://github.com/udbc/catalogue/archive/1.0.1.tar.gz

```
  * Extract the artifact, and copy images directory

e.g.
```
tar -xzf 1.0.1.tar.gz
cd catalogue-1.0.1
cp -r  images  /images
```


### Deploy the Catalogue App

Create releases directory

```
mkdir /opt/apps/catalogue/releases

```
Download the [release artifact from this page](https://s3.amazonaws.com/sod-openedx/catalogue/catalogue)

e.g.

```
cd  /opt/apps/catalogue/releases

wget -c https://s3.amazonaws.com/sod-openedx/catalogue/catalogue
```


where **catalogue** is a binary

create a symlink
```
ln -s /opt/apps/catalogue/releases/catalogue /opt/

```

Launch the app
```
/opt/catalogue -port 7081 -images=/images/ -DSN 'dbuser:password@tcp(localhost:3306)/databasename'
```

e.g.
```
/opt/catalogue -port 7081 -images=/images/ -DSN 'devops:GKkdw72Jil0ld@tcp(localhost:3306)/catalogue'

```

### API Spec

Checkout the API Spec [here](http://microservices-demo.github.io/api/index?url=https://raw.githubusercontent.com/microservices-demo/catalogue/master/api-spec/catalogue.json)


### To build this service

#### Dependencies
```
go get -u github.com/FiloSottile/gvt
gvt restore
```

#### Go tools
In order to build the project locally you need to make sure that the repository directory is located in the correct
$GOPATH directory: $GOPATH/src/github.com/microservices-demo/catalogue/. Once that is in place you can build by running:

```
cd $GOPATH/src/github.com/microservices-demo/catalogue/cmd/cataloguesvc/
go build -o catalogue
```

The result is a binary named `catalogue`, in the current directory.

#### Docker
`docker-compose build`

### To run the service on port 8080

#### Go native

If you followed to Go build instructions, you should have a "catalogue" binary in $GOPATH/src/github.com/microservices-demo/catalogue/cmd/cataloguesvc/.
To run it use:
```
./catalogue
```

#### Docker
`docker-compose up`

### Run tests before submitting PRs
`make test`

### Check whether the service is alive
`curl http://localhost:8080/health`

### Use the service endpoints
`curl http://localhost:8080/catalogue`

### Push the service to Docker Container Registry
`GROUP=weaveworksdemos COMMIT=test ./scripts/push.sh`

## Test Zipkin

To test with Zipkin

```
docker-compose -f docker-compose-zipkin.yml build
docker-compose -f docker-compose-zipkin.yml up
```
It takes about 10 seconds to seed data

you should see it at:
[http://localhost:9411/](http://localhost:9411)

be sure to hit the "Find Traces" button.  You may need to reload the page.

when done you can run:
```
docker-compose -f docker-compose-zipkin.yml down
```
