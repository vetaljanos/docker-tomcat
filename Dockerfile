FROM nologinb/docker-java:7.80

ENV CATALINA_HOME=/tomcat

RUN mkdir /tomcat

RUN apt-get update && apt-get install -y --no-install-recommends \
  wget \
  && rm -rf /var/lib/apt/lists/*

ENV TOMCAT_MAJOR 8
ENV TOMCAT_VERSION 8.0.52

ENV TOMCAT_TGZ_URLS \
  https://www.apache.org/dyn/closer.cgi?action=download&filename=tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz \
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

RUN wget -O maven.tar.gz http://apache.volia.net/maven/binaries/apache-maven-3.1.1-bin.tar.gz \
  && mkdir /opt/maven \
  && tar -xvf maven.tar.gz --strip-components=1 -C /opt/maven \
  && rm maven.tar.gz

COPY server.xml /tomcat/conf/server.xml
COPY logging.properties /tomcat/conf/logging.properties

ENV PATH=$PATH:/opt/maven/bin
ENV JAVA_OPTS=" -XX:NativeMemoryTracking=summary $JAVA_EXT_OPTS "    
ENV CATALINA_TMPDIR=/tmp

#create ssl base certificate
RUN /usr/lib/jvm/default-jvm/bin/keytool -genkey -alias tomcat -keyalg RSA -storepass changeit -keypass changeit -dname "CN=tomcat, OU=, O=, L=, S=, C="

WORKDIR $CATALINA_HOME

CMD ["bin/catalina.sh", "run"]
