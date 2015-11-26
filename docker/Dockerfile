FROM ubuntu:14.04
MAINTAINER Ryan Scott

RUN apt-get update && apt-get install -y \
    ruby-dev \
    git \
    build-essential \
    sqlite3 \
    libsqlite3-dev \
    libcurl3 \
    zlib1g-dev \
    vim

RUN git clone https://github.com/ryankscott/vend_journals.git
RUN gem install bundle
RUN cd vend_journals && bundle install

EXPOSE 4567
