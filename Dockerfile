FROM ubuntu:jammy
# MAINTAINER Hennadii Samofal <salge.cos@gmail.com>
LABEL maintainer="Hennadii Samofal <salge.cos@gmail.com>"
LABEL version="1.0"

# SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

# Generate locale C.UTF-8 for postgres and general locale data
ENV LANG=en_US.UTF-8
ENV ODOO_VERSION=17.0
ENV ODOO_RC=/etc/odoo/odoo.conf

# Retrieve the target architecture to install the correct wkhtmltopdf package
ARG TARGETARCH

# Install some deps, lessc and less-plugin-clean-css, and wkhtmltopdf

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    dirmngr \
    fonts-noto-cjk \
    git \
    gnupg \
    libffi-dev \
    libsasl2-dev \
    libldap2-dev \
    libssl-dev \
    libpq-dev \
    node-less \
    npm \
    python3 \
    python3-dev \
    python3-magic \
    python3-num2words \
    python3-odf \
    python3-pdfminer \
    python3-pip \
    python3-phonenumbers \
    python3-pyldap \
    python3-qrcode \
    python3-renderpm \
    python3-setuptools \
    python3-slugify \
    python3-vobject \
    python3-watchdog \
    python3-venv \
    python3-xlrd \
    python3-xlwt \
    postgresql-client \
    xz-utils && \
    if [ -z "${TARGETARCH}" ]; then \
    TARGETARCH="$(dpkg --print-architecture)"; \
    fi; \
    WKHTMLTOPDF_ARCH=${TARGETARCH} && \
    case ${TARGETARCH} in \
    "amd64") WKHTMLTOPDF_ARCH=amd64 && WKHTMLTOPDF_SHA=967390a759707337b46d1c02452e2bb6b2dc6d59  ;; \
    "arm64")  WKHTMLTOPDF_SHA=90f6e69896d51ef77339d3f3a20f8582bdf496cc  ;; \
    "ppc64le" | "ppc64el") WKHTMLTOPDF_ARCH=ppc64el && WKHTMLTOPDF_SHA=5312d7d34a25b321282929df82e3574319aed25c  ;; \
    esac \
    && curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_${WKHTMLTOPDF_ARCH}.deb \
    && echo ${WKHTMLTOPDF_SHA} wkhtmltox.deb | sha1sum -c - \
    && apt-get install -y --no-install-recommends ./wkhtmltox.deb \
    && rm -rf /var/lib/apt/lists/* wkhtmltox.deb \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* 

# install latest postgresql-client
# RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ jammy-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
#     && GNUPGHOME="$(mktemp -d)" \
#     && export GNUPGHOME \
#     && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
#     && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
#     && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
#     && gpgconf --kill all \
#     && rm -rf "$GNUPGHOME" \
#     && apt-get update  \
#     && apt-get install --no-install-recommends -y postgresql-client \
#     && rm -f /etc/apt/sources.list.d/pgdg.list \
#     && rm -rf /var/lib/apt/lists/*

# Install rtlcss (on Debian buster)
RUN npm install -g rtlcss


# Install Odoo
# RUN git clone --depth 1 --branch ${ODOO_VERSION} https://github.com/volleyballwinnipeg/odoo.git /odoo
RUN git clone --depth 1 --branch docker-file https://github.com/volleyballwinnipeg/odoo.git /odoo

# Install Python dependencies
# RUN python3 -m pip install --upgrade pip

# RUN python3 -m venv odoo-env
# RUN source odoo-env/bin/activate

# RUN pip3 install -r /odoo/requirements.txt

RUN python3 -m venv /odoo-env \
    && /odoo-env/bin/pip install --upgrade pip \
    && /odoo-env/bin/pip install -r /odoo/requirements.txt

# Copy entrypoint script and Odoo configuration file
COPY ./entrypoint.sh /entrypoint.sh
COPY ./debian/odoo.conf /etc/odoo/odoo.conf

# Set permissions and Mount /var/lib/odoo to allow restoring filestore and /mnt/extra-addons for users addons
RUN chown $(whoami) /etc/odoo/odoo.conf \
    && mkdir -p /mnt/extra-addons \
    && chown -R $(whoami) /mnt/extra-addons
VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]


# Expose Odoo services
EXPOSE 8069 8071 8072


COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py

# Set default user when running the container
USER odoo

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]