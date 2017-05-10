FROM docker-artifactory-poc.sln.nc/docker:17.03.0-ce

# Setup project folder
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app
VOLUME /usr/src/app

RUN apk --no-cache add git curl jq bash

COPY init.sh /init.sh
RUN chmod +x /init.sh
RUN source /init.sh

ONBUILD COPY docker-entrypoint.sh /docker-entrypoint.sh
ONBUILD RUN chmod +x /docker-entrypoint.sh

CMD ["/docker-entrypoint.sh"]