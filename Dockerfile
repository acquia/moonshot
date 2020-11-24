FROM ubuntu:xenial

RUN apt-get update \
  && apt-get install -y \
    build-essential \
    cmake \
    git \
    software-properties-common

RUN apt-add-repository -y ppa:brightbox/ruby-ng \
  && apt-get update \
  && apt-get install -y \
    ruby2.6 \
    ruby2.6-dev

RUN gem install rubygems-update -v '<3' --no-document && update_rubygems \
  && gem update bundler

