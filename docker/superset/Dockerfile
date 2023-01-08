# Based on the latest stable release
# check https://hub.docker.com/r/apache/superset/tags (search for '1.' to get releases)
FROM apache/superset:1.5.2

USER root
# Geckodriver prerequisites
RUN apt-get update \
  && apt-get -y install --no-install-recommends firefox-esr \
  && apt-get -y upgrade \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install geckodriver to support rendering charts in email alerts
ENV GECKODRIVER_VERSION=0.31.0
RUN wget https://github.com/mozilla/geckodriver/releases/download/v${GECKODRIVER_VERSION}/geckodriver-v${GECKODRIVER_VERSION}-linux64.tar.gz \
  && tar -x geckodriver -zf geckodriver-v${GECKODRIVER_VERSION}-linux64.tar.gz -O > /usr/bin/geckodriver \
  && rm geckodriver-v${GECKODRIVER_VERSION}-linux64.tar.gz \
  && chmod 755 /usr/bin/geckodriver \
  && geckodriver --version
USER superset

# Install a selection of drivers for connecting Superset to various database types and auth integrations.
#
# See here for full list of supported DBs and their connection strings:
#   https://superset.apache.org/docs/databases/installing-database-drivers
#
# - authlib + flask-oidc: Support OIDC auth
# - pyhive + trino: Support talking to Trino in Walden
RUN pip install \
  authlib==1.0.1 \
  flask-oidc==1.4.0 \
  \
  trino==0.320.0
