FROM ubuntu:24.04

RUN apt-get update && apt-get install -y curl ca-certificates git \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /home/user/agent /home/user/workspace

WORKDIR /home/user/agent

COPY e2b/agent/package.json /home/user/agent/
RUN npm install

COPY e2b/agent/run.mjs /home/user/agent/
COPY e2b/agent/server.mjs /home/user/agent/
