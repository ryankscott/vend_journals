FROM ubuntu:latest
MAINTAINER Ryan Scott 

RUN apt-get update
RUN apt-get update && apt-get install -y \
    ruby-dev \
    postgresql postgresql-contrib \
    git \
    build-essential \
    postgresql-9.3 postgresql-server-dev-9.3 libpq-dev \
    sqlite3 \
    libsqlite3-dev \
    libcurl3 \
    vim

RUN git clone https://github.com/ryankscott/vend_journals.git
RUN gem install bundle
RUN cd vend_journals && bundle install


USER postgres
RUN /etc/init.d/postgresql start && \
    psql --command "CREATE USER admin WITH SUPERUSER PASSWORD 'admin123';" &&\
    createdb -O admin vend_journals

USER root
