FROM golang:1.12

ARG VERSION

COPY . /opt/data
WORKDIR /opt/data

RUN echo $VERSION > /opt/data/pkg/version/VERSION
RUN make linux

#########################################################################################

FROM gcr.io/distroless/base
COPY --from=0 /opt/data/build/linux/turn /usr/bin/turn

WORKDIR /usr/bin

ENV REALM localhost
ENV USERS username=password
ENV UDP_PORT 3478

EXPOSE 3478

CMD ["turn"]
