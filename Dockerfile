FROM golang:1.15 AS builder

# Set some shell options for using pipes and such
SHELL [ "/bin/bash", "-euo", "pipefail", "-c" ]

# Don't call any C code (the 'scratch' base image used later won't have any libraries to reference)
ENV CGO_ENABLED=0

# Use Go modules
ENV GO111MODULE=on

# Precompile the entire Go standard library into a Docker cache layer: useful for other projects too!
# cf. https://www.reddit.com/r/golang/comments/hj4n44/improved_docker_go_module_dependency_cache_for/
RUN go install -ldflags="-buildid= -w" -trimpath -v std

WORKDIR /go/src/go.jlucktay.dev/zxcvbn-go

# This will save Go dependencies in the Docker cache, until/unless they change
COPY go.mod go.sum ./

# Download and precompile all third party libraries
RUN go mod graph | awk '$1 !~ "@" { print $2 }' | xargs --no-run-if-empty go get -ldflags="-buildid= -w" -trimpath -v

# Add the sources
COPY . .

# Compile! Should only compile our project since everything else has been precompiled by now, and future
# (re)compilations will leverage the same cached layer(s)
RUN go build -ldflags="-buildid= -w" -trimpath -v -o /bin/zxcvbn-go go.jlucktay.dev/zxcvbn-go/testapp

FROM scratch AS runner

# Bring binary over
COPY --from=builder /bin/zxcvbn-go /bin/zxcvbn-go

ENTRYPOINT [ "/bin/zxcvbn-go" ]
