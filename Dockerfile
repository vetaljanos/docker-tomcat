FROM nologinb/java8

ENV CATALINA_HOME=/tomcat 

RUN groupadd tomcat && useradd -s /bin/bash -M -d /tomcat -g tomcat tomcat

RUN mkdir /tomcat

RUN apt-get update && apt-get install -y --no-install-recommends \
  wget \
  easy-rsa \
  && rm -rf /var/lib/apt/lists/*

ENV TOMCAT_MAJOR 8
ENV TOMCAT_VERSION 8.5.24

ENV TOMCAT_TGZ_URLS \
# https://issues.apache.org/jira/browse/INFRA-8753?focusedCommentId=14735394#comment-14735394
  https://www.apache.org/dyn/closer.cgi?action=download&filename=tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz \
# if the version is outdated, we might have to pull from the dist/archive :/
  https://www-us.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz \
  https://www.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz \
  https://archive.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz

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
  tar -xvf tomcat.tar.gz --strip-components=1 -C /tomcat; \
  rm tomcat/bin/*.bat; \
  rm -Rf tomcat/webapps/*; \
  rm tomcat.tar.gz*

COPY server.xml /tomcat/conf/server.xml
COPY logging.properties /tomcat/conf/logging.properties

ENV JAVA_OPTS=" -XX:NativeMemoryTracking=summary -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -XX:+ExitOnOutOfMemoryError "    
ENV CATALINA_TMPDIR=/tmp

#create ssl base certificate
RUN make-cadir /ssl \
  && cd /ssl \
  && . ./vars \
  && ./clean-all \
  && ./pkitool --initca \
  && ./pkitool init-pki \
  && ./pkitool --server tomcat \
  && mkdir -p /tomcat/conf/Catalina/localhost \
  && chmod -R g+rx /ssl /ssl/keys \
  && chmod g+r /ssl/keys/ca.crt /ssl/keys/tomcat.* \
  && chown -R tomcat:tomcat /tomcat \
  && chown -R root:tomcat /ssl \
  && chown -R root:tomcat /ssl/keys 

USER tomcat:tomcat

WORKDIR $CATALINA_HOME

CMD ["bin/catalina.sh", "run"]
