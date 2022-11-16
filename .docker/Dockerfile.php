ARG CLI_IMAGE
ARG IMAGE_VERSION=latest

FROM ${CLI_IMAGE} as cli

FROM uselagoon/php-8.1-fpm:${IMAGE_VERSION}

COPY --from=cli /app /app
