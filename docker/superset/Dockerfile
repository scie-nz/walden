# Based on the latest stable release
# check https://hub.docker.com/r/apache/superset/tags (search for '1.' to get releases)
FROM apache/superset:4.1.1

USER root
# Geckodriver prerequisites
RUN apt-get update \
  && apt-get -y install --no-install-recommends firefox-esr \
  && apt-get -y upgrade \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install geckodriver to support rendering charts in email alerts
ENV GECKODRIVER_VERSION=0.35.0
RUN wget https://github.com/mozilla/geckodriver/releases/download/v${GECKODRIVER_VERSION}/geckodriver-v${GECKODRIVER_VERSION}-linux64.tar.gz \
  && tar -x geckodriver -zf geckodriver-v${GECKODRIVER_VERSION}-linux64.tar.gz -O > /usr/bin/geckodriver \
  && rm geckodriver-v${GECKODRIVER_VERSION}-linux64.tar.gz \
  && chmod 755 /usr/bin/geckodriver \
  && geckodriver --version
USER superset

# Install a selection of drivers for connecting Superset to various database types and auth integrations.
#
# See here for full list of supported DBs and their connection strings:
#   https://superset.apache.org/docs/configuration/databases/
#
# - authlib + flask-oidc: Support OIDC auth
# - trino: Support talking to Trino in Walden
RUN pip3 install --break-system-packages \
  authlib==1.4.0 \
  flask-oidc==2.2.2 \
  \
  trino==0.332.0
