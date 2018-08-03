FROM docker-artifactory.sln.nc/docker:17.12.0-ce

# Setup project folder
RUN mkdir -p /srv/speed
WORKDIR /srv/speed
VOLUME /srv/speed

RUN apk --no-cache add git curl jq bash sed grep

COPY yq /usr/local/bin/yq
RUN chmod +x /usr/local/bin/yq

COPY init.sh /init.sh
RUN chmod +x /init.sh

ONBUILD COPY docker-entrypoint.sh /docker-entrypoint.sh
ONBUILD RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
