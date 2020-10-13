FROM centos:7.1.1503

RUN yum -y install libstdc++ gcc-c++ perl java-1.8.0-openjdk-devel perl-DBI perl-DBD-SQLite git

COPY . /opt/meister/

ENTRYPOINT /bin/sh
