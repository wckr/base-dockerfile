FROM ruby:2.5.0-slim-stretch AS builder
FROM debian:stretch-slim

MAINTAINER ixkaito <ixkaito@gmail.com>

RUN apt-get update \
  && apt-get clean \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    less \
    libyaml-0-2 \
    mysql-server \
    mysql-client \
    nano \
    openssh-client \
    php7.0 \
    php7.0-bz \
    php7.0-cli \
    php7.0-curl \
    php7.0-gd \
    php7.0-mbstring \
    php7.0-mysql \
    php7.0-xdebug \
    php7.0-xml \
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
ADD xdebug.ini /etc/php/7.0/cli/conf.d/20-xdebug.ini

#
# `mysqld_safe` patch
# @see https://github.com/wckr/wocker/pull/28#issuecomment-195945765
#
RUN sed -i -e 's/file) cmd="$cmd >> "`shell_quote_string "$err_log"`" 2>\&1" ;;/file) cmd="$cmd >> "`shell_quote_string "$err_log"`" 2>\&1 \& wait" ;;/' /usr/bin/mysqld_safe

#
# MariaDB settings & install WordPress
#
ENV WWW=/var/www
ENV DOCROOT=${WWW}/wordpress
RUN adduser --uid 1000 --gecos '' --disabled-password wocker \
  && mkdir -p ${DOCROOT}
ADD wp-cli.yml ${WWW}
WORKDIR ${DOCROOT}
RUN sed -i -e "s/^bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mariadb.conf.d/50-server.cnf \
  && service mysql start \
  && mysqladmin -u root password root \
  && mysql -uroot -proot -e \
    "CREATE DATABASE wordpress DEFAULT CHARACTER SET utf8; grant all privileges on wordpress.* to wordpress@'%' identified by 'wordpress';" \
  && wp core download --allow-root \
  && wp core config --allow-root \
    --dbname=wordpress \
    --dbuser=wordpress \
    --dbpass=wordpress \
    --dbhost=localhost \
  && chown -R wocker:wocker ${DOCROOT}
