# Create base image with dependencies
# needed by both builder and final
FROM --platform=linux/x86_64 ubuntu:16.04 as base-image

RUN apt-get update && apt-get install -y --allow-unauthenticated build-essential \
    libmysqlclient-dev \
    liblua5.3-dev \
    libdb5.3-dev \
    libssl-dev \
    libboost-all-dev

COPY scripts /app/scripts
RUN ln -s /app/scripts/swgemu.sh /usr/bin/swgemu

# Create builder image from base and add
# needed items for building the project
FROM base-image as build-image
RUN apt-get install -y cmake \
    ninja-build \
    git \
    default-jre \
    curl

# builder image to build Core3
# this is separate to facilicate using
# the prior layer for local development
FROM build-image as builder

RUN curl -L https://github.com/krallin/tini/releases/download/v0.18.0/tini -o /usr/bin/tini

WORKDIR /app
COPY ./Core3 .

# This is a hack to make the /app folder the root of it's own
# git repo. Without this section git will treat is as a submodule
# of swgemu-docker but will be missing the .git folder and fail all git commands
RUN rm .git
COPY .git/modules/Core3/. .git/
RUN sed -i 's/..\/..\/Core3\///' .git/modules/MMOCoreORB/utils/engine3/config && \
    sed -i 's/worktree.*//' .git/config && \
    sed -i 's/..\/.git\/modules\/Core3\//.git\//' MMOCoreORB/utils/engine3/.git

WORKDIR /app/MMOCoreORB
RUN make build-ninja-debug

# Create final image that could be used as a 
# lighter-weight production image
FROM base-image as final

COPY --from=builder /usr/bin/tini /usr/bin/tini
RUN chmod a+x /usr/bin/tini

WORKDIR /app/MMOCoreORB/bin
COPY --from=builder /app/MMOCoreORB/bin .

# tini is needed as core3 does not explicitly handle SIGTERM signals
ENTRYPOINT ["tini", "--"]
CMD ["swgemu", "start"]
