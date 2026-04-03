FROM golang:1.22-alpine AS deps

RUN apk add --no-cache ca-certificates git

ENV GOPATH=/go:/go/src/github.com/microservices-demo/catalogue/vendor \
    GO111MODULE=off \
    CGO_ENABLED=0 \
    GOOS=linux

WORKDIR /go/src/github.com/microservices-demo/catalogue

# Copy only source files first so dependency downloads can be cached.
COPY *.go ./
COPY cmd ./cmd
COPY vendor/manifest ./vendor/manifest

RUN GO111MODULE=on go install github.com/FiloSottile/gvt@latest \
    && /go/bin/gvt restore

FROM golang:1.22-alpine AS build

ENV GOPATH=/go:/go/src/github.com/microservices-demo/catalogue/vendor \
    GO111MODULE=off \
    CGO_ENABLED=0 \
    GOOS=linux

WORKDIR /go/src/github.com/microservices-demo/catalogue

COPY --from=deps /go /go
COPY images ./images

RUN go build -trimpath -ldflags="-s -w" -o /out/catalogue ./cmd/cataloguesvc

FROM alpine:3.20 AS runtime

RUN apk add --no-cache ca-certificates libcap \
    && addgroup -S catalogue \
    && adduser -S -G catalogue -u 10001 catalogue

WORKDIR /app

COPY --from=build /out/catalogue /usr/local/bin/catalogue
# Only the runtime assets required by the service are copied into the final image.
COPY --from=build --chown=catalogue:catalogue /go/src/github.com/microservices-demo/catalogue/images ./images

RUN setcap 'cap_net_bind_service=+ep' /usr/local/bin/catalogue

USER catalogue

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/catalogue"]
CMD ["-port=80", "-images=/app/images"]