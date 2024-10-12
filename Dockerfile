FROM docker.io/elixir:1.14-otp-26-alpine as build

ARG REBASED_VERSION=main
ENV MIX_ENV=prod

# git curl build-essential postgresql postgresql-contrib cmake libmagic-dev imagemagick ffmpeg libimage-exiftool-perl nginx certbot unzip libssl-dev automake autoconf libncurses5-dev fasttext
RUN apk add --no-cache git gcc g++ musl-dev make cmake file-dev ncurses-dev postgresql-client \
        imagemagick libmagic ffmpeg exiftool automake autoconf libressl-dev

WORKDIR /rebased
RUN git clone --no-checkout https://gitlab.com/soapbox-pub/rebased . && \
    git checkout ${REBASED_VERSION}

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get --only prod &&\
    mkdir release && \
    mix release --path release


FROM docker.io/elixir:1.14-otp-26-alpine as runner

LABEL org.opencontainers.image.source=https://github.com/SeolHa314/docker-rebased
LABEL org.opencontainers.image.description="Unofficial Rebased image for containers"
LABEL org.opencontainers.image.licenses="AGPL-3.0"

ARG UID=1004
ARG GID=1004
ENV MIX_ENV=prod
ENV HOME=/home/pleroma
ENV DATA=/data

RUN apk add --no-cache shadow git curl imagemagick file-dev ffmpeg \
        postgresql-client fasttext ncurses exiftool libressl-dev

WORKDIR /pleroma

ADD ./docker-start.sh /pleroma/docker-start.sh
RUN chmod +x /pleroma/docker-start.sh && \
    useradd -s /bin/false -m -d ${HOME} -u ${UID} -U pleroma && \
    groupmod -g ${GID} pleroma && \
    mkdir -p ${DATA}/uploads && \
    mkdir -p ${DATA}/static && \
    chown -R pleroma:pleroma ${DATA} && \
    mkdir -p /etc/pleroma && \
    chown -R pleroma /etc/pleroma && \
    mkdir -p /usr/share/fasttext && \
    curl -L https://dl.fbaipublicfiles.com/fasttext/supervised-models/lid.176.ftz -o /usr/share/fasttext/lid.176.ftz && \
    chmod 0644 /usr/share/fasttext/lid.176.ftz

USER pleroma

COPY --from=build --chown=pleroma:pleroma /rebased/release /pleroma
COPY --chown=pleroma config.exs /etc/pleroma/config.exs
RUN chmod o= /etc/pleroma/config.exs

ENTRYPOINT [ "/pleroma/docker-start.sh" ]
