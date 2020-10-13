FROM registry.fedoraproject.org/fedora:28
MAINTAINER OpenMake

COPY . /opt/meister/client/
RUN yum -y install libstdc++

ENV OPENMAKE_SERVER="http://exchange.openmakesoftware.com:28080/openmake"
ENV PATH="/opt/meister/client/bin:${PATH}"

ENTRYPOINT /bin/sh
