FROM ghcr.io/cirruslabs/flutter:3.41.6

ARG CFT_VERSION=147.0.7727.24
ARG PB_VERSION=0.36.8

WORKDIR /workspace

# Install system dependencies early for better layer caching.
# These layers change infrequently and should be cached when possible.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        unzip \
        xauth \
        xvfb \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Chrome for Testing and the matching ChromeDriver.
# Ubuntu's chromium/chromedriver packages in this image are snap wrappers,
# which fail in containers without snapd.
RUN curl -fsSL "https://storage.googleapis.com/chrome-for-testing-public/${CFT_VERSION}/linux64/chrome-linux64.zip" -o /tmp/chrome.zip \
    && curl -fsSL "https://storage.googleapis.com/chrome-for-testing-public/${CFT_VERSION}/linux64/chromedriver-linux64.zip" -o /tmp/chromedriver.zip \
    && unzip /tmp/chrome.zip -d /opt \
    && unzip /tmp/chromedriver.zip -d /opt \
    && printf '%s\n' '#!/usr/bin/env sh' 'exec /opt/chrome-linux64/chrome --no-sandbox --disable-dev-shm-usage "$@"' > /usr/local/bin/google-chrome \
    && ln -sf /opt/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver \
    && chmod +x /usr/local/bin/google-chrome /usr/local/bin/chromedriver \
    && rm -f /tmp/chrome.zip /tmp/chromedriver.zip

ENV CHROME_EXECUTABLE=/usr/local/bin/google-chrome
ENV CHROMEDRIVER_BINARY=/usr/local/bin/chromedriver

# Download and install PocketBase 0.28.2 to /usr/local/bin.
# Placed before COPY to cache stable dependency layer.
RUN curl -L \
    "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_amd64.zip" \
    -o /tmp/pb.zip \
    && unzip /tmp/pb.zip pocketbase -d /usr/local/bin/ \
    && chmod +x /usr/local/bin/pocketbase \
    && rm /tmp/pb.zip

# Copy workspace last to preserve cache when code changes.
COPY . /workspace

CMD ["./scripts/run-local-tests.sh"]
