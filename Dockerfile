FROM ubuntu:16.04
MAINTAINER Seth Fitzsimmons <seth@mojodna.net>

ARG http_proxy

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
  apt-get install -y --no-install-recommends software-properties-common && \
  add-apt-repository ppa:ubuntugis/ubuntugis-unstable && \
  apt-get update && \
  apt-get upgrade -y && \
  apt-get install -y --no-install-recommends \
    apt-transport-https \
    build-essential \
    gdal-bin \
    git \
    libgdal-dev \
    lsb-release \
    python-dev \
    python-pip \
    python-setuptools \
    python-wheel \
    software-properties-common \
    wget && \
  wget -q -O - https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - && \
  add-apt-repository -s "deb https://deb.nodesource.com/node_4.x $(lsb_release -c -s) main" && \
  apt-get update && \
  apt-get install --no-install-recommends -y nodejs && \
  apt-get clean

COPY package.json /app/package.json
COPY requirements.txt /app/requirements.txt

WORKDIR /app

RUN pip install -U "numpy==1.13.0" && \
  pip install -Ur requirements.txt && \
  pip install -U "gevent==1.2.2" "gunicorn==19.7.1" && \
  rm -rf /root/.cache

RUN npm install && \
  rm -rf /root/.npm

COPY . /app

RUN mkdir -p /app/{imagery,uploads} && chown nobody:nogroup /app/{imagery,uploads}

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/app/node_modules/.bin
# override this accordingly; should be 2-4x $(nproc)
ENV WEB_CONCURRENCY 4
EXPOSE 8000
USER nobody
VOLUME /app/imagery
VOLUME /app/uploads

ENTRYPOINT ["gunicorn", "-k", "gevent", "-b", "0.0.0.0", "--timeout", "300", "--access-logfile", "-", "app:app"]
