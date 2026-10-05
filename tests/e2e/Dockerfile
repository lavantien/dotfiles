# Linux e2e harness image: bare LTS box with only the tools a fresh machine
# ships plus what the scripts themselves require. ubuntu:26.04 is the current
# LTS and the README's stated floor.
FROM ubuntu:26.04

ENV DEBIAN_FRONTEND=noninteractive

# sudo and curl: bootstrap prerequisites. git: deploy and hooks. ca-certificates:
# any https call. vim: healthcheck's required editor falls back from nvim. zsh:
# the shell the deployed configs target.
RUN apt-get update \
	&& apt-get install -y --no-install-recommends sudo curl git ca-certificates vim zsh \
	&& rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash tester \
	&& echo 'tester ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/tester \
	&& chmod 440 /etc/sudoers.d/tester \
	&& mkdir /work \
	&& chown tester:tester /work

USER tester
ENV HOME=/home/tester
WORKDIR /work
