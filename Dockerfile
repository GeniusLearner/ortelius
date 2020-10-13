FROM meister:latest

WORKDIR /build/

COPY . /workspace

ENTRYPOINT [ "/bin/sh" ]
