# Start with Rocky Linux 9.3 as the base image
FROM rockylinux:9.3

# Set environment variables
ENV USER_ID=clos21
ENV ID=06307
ENV SCRATCH=/scratch/${ID}/${USER_ID}
ENV WORK=/work/${ID}/${USER_ID}
ENV HOME=/home/${USER_ID}

# Install necessary packages
RUN dnf update -y && \
    dnf install -y \
    wget \
    gcc \
    gcc-c++ \
    make \
    lua \
    lua-devel \
    tcl \
    tcl-devel \
    && dnf clean all

# Install Lmod
RUN wget https://github.com/TACC/Lmod/archive/8.7.44.tar.gz && \
    tar xvf 8.7.44.tar.gz && \
    cd Lmod-8.7.44 && \
    ./configure --prefix=/opt/apps && \
    make install && \
    cd .. && \
    rm -rf Lmod-8.7.44 8.7.44.tar.gz

# Set up Lmod
RUN echo '. /opt/apps/lmod/lmod/init/profile' >> /etc/profile.d/z00_lmod.sh

# Create directories
RUN mkdir -p ${SCRATCH} ${WORK} ${HOME}

# Create user and set ownership
RUN useradd -m -d ${HOME} -s /bin/bash ${USER_ID}
RUN chown -R ${USER_ID}:${USER_ID} ${SCRATCH} ${WORK} ${HOME}

# Switch to the user
USER ${USER_ID}

# Set working directory
WORKDIR ${HOME}

# Set default command
CMD ["/bin/bash"]