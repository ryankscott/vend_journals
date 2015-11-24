FROM ubuntu:latest
MAINTAINER Ryan Scott

RUN apt-get update
RUN apt-get update && apt-get install -y \
    ruby-dev \
    git \
    build-essential \
    sqlite3 \
    libsqlite3-dev \
    libcurl3 \
    vim

RUN git clone https://github.com/ryankscott/vend_journals.git
RUN gem install bundle
RUN cd vend_journals && bundle install

EXPOSE 4567
