FROM eclipse-temurin:21-jre
LABEL maintainer="Ashkan Rafiee <dockerburp.icky338@passmail.net>"

# Load environment variables from .env file
ARG BURPSUITE_VERSION=2025.11
ARG BURPSUITE_TYPE=community
ARG BURPSUITE_HOME=/home/burp
ARG BURPSUITE_MODE=download
ARG JAVA_OPTS="-Dawt.useSystemAAFontSettings=gasp -Dswing.aatext=true -Dsun.java2d.xrender=true -XX:+UnlockExperimentalVMOptions -XshowSettings:vm"
ARG DISPLAY=host.docker.internal:0
ARG BURP_PROXY_PORT=8080
ARG ENABLE_WEB_UI=true
ARG VNC_DISPLAY=:1
ARG VNC_PORT=5901
ARG NOVNC_PORT=6080
ARG NOVNC_WEB_DIR=/usr/share/novnc
ARG XVFB_GEOMETRY=1920x1080x24
ARG VNC_PASSWORD=burp

ENV BURPSUITE_VERSION=${BURPSUITE_VERSION} \
    BURPSUITE_TYPE=${BURPSUITE_TYPE} \
    BURPSUITE_MODE=${BURPSUITE_MODE} \
    HOME=${BURPSUITE_HOME} \
    JAVA_OPTS=${JAVA_OPTS} \
    DISPLAY=${DISPLAY} \
    ENABLE_WEB_UI=${ENABLE_WEB_UI} \
    VNC_DISPLAY=${VNC_DISPLAY} \
    VNC_PORT=${VNC_PORT} \
    NOVNC_PORT=${NOVNC_PORT} \
    NOVNC_WEB_DIR=${NOVNC_WEB_DIR} \
    XVFB_GEOMETRY=${XVFB_GEOMETRY} \
    VNC_PASSWORD=${VNC_PASSWORD}
  
RUN apt update && apt full-upgrade -y && apt autoremove -y && \
    apt install -y --no-install-recommends \
    curl \
    openssl \
    ca-certificates \
    fontconfig \
    libxext6 \
    libxrender1 \
    libxtst6 \
    libxi6 \
    libxrandr2 \
    libxinerama1 \
    xvfb \
    x11vnc \
    fluxbox \
    novnc \
    websockify \
    && rm -rf /var/lib/apt/lists/*

# Provide an index page that auto-loads the noVNC client
COPY assets/index.html /usr/share/novnc/index.html

# Create user and home directory
RUN groupadd --system burp && \
    useradd --system --gid burp --home /home/burp --shell /sbin/nologin burp

# Create necessary directories with proper permissions
RUN mkdir -p /home/burp/.java/.userPrefs \
    /home/burp/.Burp \
    /home/burp/config && \
    chown -R burp:burp /home/burp


COPY --chown=burp:burp scripts/ config burpsuite.jar* /home/burp/

# Run download.sh at build time if BURPSUITE_MODE=download
RUN if [ "$BURPSUITE_MODE" = "download" ]; then \
        /home/burp/download.sh; \
    fi

# Switch to non-root user
USER burp
WORKDIR ${HOME}

# Expose ports
EXPOSE ${BURP_PROXY_PORT} ${NOVNC_PORT}

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${BURP_PROXY_PORT} || exit 1

# Run entrypoint script
ENTRYPOINT ["/home/burp/entrypoint.sh"]
CMD ["burpsuite.jar"]