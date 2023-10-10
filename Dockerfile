FROM rockylinux:8

# --with-pam_dir=/usr/lib64/security/

# LABEL org.opencontainers.image.source="https://github.com/giovtorres/slurm-docker-cluster" \
#      org.opencontainers.image.title="slurm-docker-cluster" \
#      org.opencontainers.image.description="Slurm Docker cluster on Rocky Linux 8" \
#      org.label-schema.docker.cmd="docker-compose up -d" \
#      maintainer="Giovanni Torres"

ARG SLURM_TAG=slurm-23-02-5-1
ARG GOSU_VERSION=1.11
ARG NODE_MAJOR=20
ARG JUPYTERLAB_VERSION=3.2.9

RUN set -ex \
    && yum makecache \
    && yum -y update \
    && yum -y install dnf-plugins-core \
	&& yum -y install epel-release \
    && yum config-manager --set-enabled powertools \
    && yum -y install \
       wget \
       bzip2 \
       perl \
       gcc \
       gcc-c++\
       git \
       gnupg \
       make \
       munge \
       munge-devel \
       python3.11-devel \
       python3.11-pip \
       python3.11 \
       mariadb-server \
       mariadb-devel \
       psmisc \
       bash-completion \
       vim-enhanced \
       json-c-devel \
	   cmake \
	   jansson-devel \
	   libjwt-devel \
	   libyaml \
	   libtool \
	   net-tools \
	   nc \
	   curl \
	   dirmngr \
	   ca-certificates \
	   sudo \
    && yum clean all \
    && rm -rf /var/cache/yum

RUN alternatives --set python /usr/bin/python3.11
RUN alternatives --set python3 /usr/bin/python3.11
#RUN alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11

RUN pip3 install Cython nose

RUN set -ex \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-amd64.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -rf "${GNUPGHOME}" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true

RUN curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
RUN adduser -m -s /usr/bin/bash admin
RUN echo "admin:admin" | chpasswd 
RUN usermod -aG wheel admin
RUN echo "admin     ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

RUN yum install nodejs libffi-devel -y && npm install -g configurable-http-proxy && pip3 install jupyterlab==${JUPYTERLAB_VERSION}

RUN yum install openmpi-devel -y && export CC=/usr/lib64/openmpi/bin/mpicc && pip3 install mpi4py && pip3 install jupyterlab_slurm

RUN set -x \
    && git clone https://github.com/nodejs/http-parser.git \
	&& cd http-parser \
	&& make \
	&& make install \
	&& ldconfig

RUN set -x \
    && git clone https://github.com/yaml/libyaml.git \
	&& cd libyaml \
	&& ./bootstrap \
	&& ./configure \
	&& make \
	&& make install

RUN set -x \
    && git clone -b ${SLURM_TAG} --single-branch --depth=1 https://github.com/SchedMD/slurm.git \
    && pushd slurm \
    && ./configure --enable-debug --prefix=/usr --sysconfdir=/etc/slurm \
        --with-mysql_config=/usr/bin  --libdir=/usr/lib64 \
		--enable-pam --with-pam_dir=/usr/lib64/security --without-shared-libslurm \
        --enable-slurmrestd --with-jwt=/usr --with-http-parser=/usr/local --with-yaml=/usr/local \
    && make install \
    && install -D -m644 etc/cgroup.conf.example /etc/slurm/cgroup.conf.example \
    && install -D -m644 etc/slurm.conf.example /etc/slurm/slurm.conf.example \
    && install -D -m644 etc/slurmdbd.conf.example /etc/slurm/slurmdbd.conf.example \
    && install -D -m644 contribs/slurm_completion_help/slurm_completion.sh /etc/profile.d/slurm_completion.sh \
    && popd \
    && rm -rf slurm \
    && groupadd -r --gid=990 slurm \
    && useradd -r -g slurm --uid=990 slurm \
    && mkdir /etc/sysconfig/slurm \
        /var/spool/slurmd \
        /var/run/slurmd \
        /var/run/slurmdbd \
        /var/lib/slurmd \
        /var/log/slurm \
        /data \
    && touch /var/lib/slurmd/node_state \
        /var/lib/slurmd/front_end_state \
        /var/lib/slurmd/job_state \
        /var/lib/slurmd/resv_state \
        /var/lib/slurmd/trigger_state \
        /var/lib/slurmd/assoc_mgr_state \
        /var/lib/slurmd/assoc_usage \
        /var/lib/slurmd/qos_usage \
        /var/lib/slurmd/fed_mgr_state \
    && chown -R slurm:slurm /var/*/slurm* \
    && /sbin/create-munge-key

COPY slurmrestd.conf /etc/slurm/slurmrestd.conf
COPY slurm.conf /etc/slurm/slurm.conf
COPY slurmdbd.conf /etc/slurm/slurmdbd.conf
RUN set -x \
    && chown slurm:slurm /etc/slurm/slurm.conf \
    && chmod 600 /etc/slurm/slurm.conf \
    && chown slurm:slurm /etc/slurm/slurmdbd.conf \
    && chmod 600 /etc/slurm/slurmdbd.conf \
    && chown slurm:slurm /etc/slurm/slurmrestd.conf \
    && chmod 600 /etc/slurm/slurmrestd.conf \
	&& dd if=/dev/random of=/etc/slurm/jwt_hs256.key bs=32 count=1 \
	&& chown slurm:slurm /etc/slurm/jwt_hs256.key \
	&& chmod 600 /etc/slurm/jwt_hs256.key

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["slurmdbd"]
