FROM ghcr.io/prefix-dev/pixi:latest
USER root
# For security reasons, SSL certificates and timezone database must be installed by host package manager
RUN apt-get update && apt-get -y install ca-certificates tzdata libgl1 libgomp1 less ttyd
# Use bash as default shell instead of dash
RUN ln -sf /bin/bash /bin/sh  

RUN useradd --no-log-init --create-home --shell /bin/bash --uid 1000 --no-user-group jovyan
COPY --chown=jovyan --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

USER jovyan
ENV PYDEVD_DISABLE_FILE_VALIDATION=1
WORKDIR /home/jovyan
CMD ["entrypoint.sh"]