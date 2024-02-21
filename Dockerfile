FROM elixir:1.14-otp-24-alpine as build

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


FROM elixir:1.14-otp-26-alpine as runner

ARG UID=998
ARG GID=998
ENV MIX_ENV=prod
ENV HOME=/home/pleroma
ENV DATA=/data

RUN apk add --no-cache shadow git curl imagemagick file-dev ffmpeg perl-image-exiftool \
        postgresql-client fasttext ncurses

WORKDIR /pleroma

RUN useradd -s /bin/false -m -d ${HOME} -u ${UID} -U pleroma && \
    groupmod -g ${GID} pleroma && \
    mkdir -p ${DATA}/uploads && \
    mkdir -p ${DATA}/static && \
    chown -R pleroma ${DATA} && \
    mkdir -p /etc/pleroma && \
    chown -R pleroma /etc/pleroma && \
    mkdir -p /usr/share/fasttext && \
    curl -L https://dl.fbaipublicfiles.com/fasttext/supervised-models/lid.176.ftz -o /usr/share/fasttext/lid.176.ftz && \
    chmod 0644 /usr/share/fasttext/lid.176.ftz

USER pleroma

ADD ./docker-start.sh /pleroma/docker-start.sh
COPY --from=build --chown=pleroma:pleroma /rebased/release /pleroma
COPY --chown=pleroma config.exs /etc/pleroma/prod.secret.exs

EXPOSE 4000
ENTRYPOINT [ "/pleroma/docker-start.sh" ]
