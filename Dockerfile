FROM alpine:3.21.3

LABEL org.opencontainers.image.source="https://github.com/CyberHotline/itflow-docker"

# Set up ENVs that will be utilized in compose file.
ENV TZ=Africa/Cairo
ENV ITFLOW_NAME="CyberHotline IT Desk"
ENV ITFLOW_URL=desk.cyberhotline.net
ENV ITFLOW_PORT=8080
ENV ITFLOW_REPO=github.com/cyberhotline/itflow
ENV ITFLOW_REPO_BRANCH=main
ENV ITFLOW_LOG_LEVEL=notice
ENV ITFLOW_DB_HOST=itflow-db
ENV ITFLOW_DB_PASS=null

# Set timezone from TZ ENV
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# PREREQS: php php-intl php-mysqli php-imap php-curl libapache2-mod-php mariadb-server git -y
# Upgrade, then install prereqs.
RUN apk update && apk upgrade

# Basic Requirements
RUN apk add \
    git\
    apache2\
    php84\
    whois\
    bind-tools\
    tzdata

# Alpine quality of life installs
RUN apk add \
    vim\
    nano

# Install & enable php extensions
RUN apk add \ 
    php84-intl\
    php84-mysqli\
    php84-curl\
    php84-imap\
    php84-pecl-mailparse\
    php84-gd\
    php84-mbstring\
    php84-ctype\
    php84-session

# Install PHP into Apache
RUN apk add \
    php84-apache2

# Set the work dir to the git repo. 
WORKDIR /var/www/html

# Edit php.ini file

RUN sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 500M/g' /etc/php84/php.ini && \
    sed -i 's/post_max_size = 8M/post_max_size = 500M/g' /etc/php84/php.ini && \
    sed -i 's/max_execution_time = 30/max_execution_time = 300/g' /etc/php84/php.ini

# Entrypoint
# On every run of the docker file, perform an entrypoint that verifies the container is good to go.
COPY entrypoint.sh /usr/bin/

# Create crontab entries

RUN echo "0       1       *       *       *       /usr/bin/php84 /var/www/html/scripts/cron.php" >> /etc/crontabs/apache
RUN echo "*       *       *       *       *       /usr/bin/php84 /var/www/html/scripts/cron_ticket_email_parser.php" >> /etc/crontabs/apache
RUN echo "*       *       *       *       *       /usr/bin/php84 /var/www/html/scripts/cron_mail_queue.php" >> /etc/crontabs/apache
RUN echo "0       2       *       *       *       /usr/bin/php84 /var/www/html/scripts/cron_certificate_refresher.php" >> /etc/crontabs/apache
RUN echo "0       3       *       *       *       /usr/bin/php84 /var/www/html/scripts/cron_domain_refresher.php" >> /etc/crontabs/apache

RUN chmod +x /usr/bin/entrypoint.sh

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/apache2/access.log && ln -sf /dev/stderr /var/log/apache2/error.log

ENTRYPOINT [ "entrypoint.sh" ]

# Expose the apache port
EXPOSE $ITFLOW_PORT

# Start the httpd service and have logs appear in stdout
CMD [ "httpd", "-D", "FOREGROUND" ]
