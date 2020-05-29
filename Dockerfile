FROM debian:9

ENV TOMCAT_MAJOR 8
ENV TOMCAT_VERSION 8.5.55
ENV TOMCAT_TGZ_URLS \
# https://issues.apache.org/jira/browse/INFRA-8753?focusedCommentId=14735394#comment-14735394
  https://www.apache.org/dyn/closer.cgi?action=download&filename=tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz \
# if the version is outdated, we might have to pull from the dist/archive :/
  https://www-us.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz \
  https://www.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz \
  https://archive.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz

RUN apt-get update && apt-get install -y --no-install-recommends \
  wget \
  ca-certificates

RUN mkdir -p /build/tomcat

RUN set -eux; \
  \
  success=; \
  for url in $TOMCAT_TGZ_URLS; do \
    if wget -O tomcat.tar.gz "$url"; then \
      success=1; \
      break; \
    fi; \
  done; \
  [ -n "$success" ]; \
  tar -xvf tomcat.tar.gz --strip-components=1 -C /build/tomcat; \
  rm /build/tomcat/bin/*.bat; \
  rm -Rf /build/tomcat/webapps/*

SHELL ["/bin/bash", "-c"]

#create ssl base certificate
RUN mkdir -p /build/ssl && cd /build/ssl
RUN openssl genrsa  -out /build/ssl/ca-key.pem
RUN openssl req -nodes -x509 -key /build/ssl/ca-key.pem \
    -subj "/C=CC/ST=ST/L=L/O=O/OU=OU/CN=Temporary CA" \
    -extensions san \
    -config <(echo -e '[req]\ndistinguished_name=req \n [san] \n basicConstraints=critical,CA:TRUE,pathlen:0 \n keyUsage = cRLSign, keyCertSign, digitalSignature') \
    -days 7300 \
    -out /build/ssl/ca.pem 
RUN openssl genrsa -out /build/ssl/tomcat-key.pem
RUN openssl req -new \
    -subj "/C=CC/ST=ST/L=L/O=O/OU=OU/CN=tomcat.temporary.addr" \
    -key /build/ssl/tomcat-key.pem \
    -out /build/ssl/tomcat.csr 
RUN openssl x509 -req \
        -in /build/ssl/tomcat.csr \
        -CA /build/ssl/ca.pem \
        -CAkey /build/ssl/ca-key.pem \
        -CAcreateserial \
        -out /build/ssl/tomcat.pem -days 365 \
        -extfile <(echo -e 'subjectAltName=IP:127.0.0.1 \n basicConstraints=CA:FALSE \n keyUsage = nonRepudiation, digitalSignature, keyEncipherment \n subjectKeyIdentifier=hash \n authorityKeyIdentifier=keyid,issuer \n issuerAltName=issuer:copy')
RUN rm -f /build/ssl/ca-key.pem /build/ssl/tomcat.csr /build/ssl/ca.srl

COPY addons /build

# main container
FROM debian:9

ENV CATALINA_HOME=/tomcat \
    JAVA_OPTS=" -XX:NativeMemoryTracking=summary -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -XX:+ExitOnOutOfMemoryError -XX:MaxRAMFraction=1 " \
    CATALINA_TMPDIR=/tmp

RUN apt-get update && apt-get upgrade -y \
  && apt -y install --no-install-recommends openjdk-8-jre \
  && rm -rf /var/lib/apt/lists/*

COPY --from=0 /build /

WORKDIR $CATALINA_HOME

CMD ["bin/catalina.sh", "run"]
