FROM ruby:2.7-slim-buster AS builder
FROM debian:buster-slim

LABEL maintainer="ixkaito <ixkaito@gmail.com>"
LABEL version="1.5.2"

RUN apt-get update \
  && apt-get clean \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    less \
    lftp \
    libyaml-0-2 \
    mariadb-client \
    mariadb-server \
    nano \
    openssh-client \
    sshpass \
    supervisor \
  && rm -rf /var/lib/apt/lists/*

ENV BIN=/usr/local/bin

#
# Copy Ruby and Gem binary
#
COPY --from=builder /usr/local/lib/ /usr/local/lib/
COPY --from=builder /usr/local/bin/ruby ${BIN}/ruby
COPY --from=builder /usr/local/bin/gem ${BIN}/gem

#
# Install Gems
#
RUN gem install wordmove --no-document

#
# Install WP-CLI
#
RUN curl -o ${BIN}/wp -L https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
  && chmod +x ${BIN}/wp

#
# Install PHPUnit
#
RUN curl -o ${BIN}/phpunit -L https://phar.phpunit.de/phpunit.phar \
  && chmod +x ${BIN}/phpunit

#
# Install Mailhog
#
RUN curl -o ${BIN}/mailhog -L https://github.com/mailhog/MailHog/releases/download/v1.0.0/MailHog_linux_amd64 \
  && chmod +x ${BIN}/mailhog

#
# Xdebug settings
#
ADD xdebug.ini /etc/php/7.3/cli/conf.d/20-xdebug.ini

#
# Setting lftp for wordmove via ftp
#
RUN echo "set ssl:verify-certificate no" >> ~/.lftp.rc

#
# Creating document root directory, adding wocker user, and MariaDB settings
#
ENV WWW=/var/www
ENV DOCROOT=${WWW}/wordpress
RUN mkdir -p ${DOCROOT} \
  && adduser --uid 1000 --gecos '' --disabled-password wocker \
  && sed -i -e "s/^bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mariadb.conf.d/50-server.cnf
ADD wp-cli.yml ${WWW}
