#!/bin/bash

function usage () {
    echo "Usage: $0 [ -h ] [ -v python_version ] [ -p install_path ] [ -b build_path ] [ -u user_base ]"
    echo "  -h: Show this help message"
    echo "  -v: Python version (default: 3.10.11)"
    echo "  -p: Installation path (default: \$SCRATCH)"
    echo "  -b: Build path (default: \$SCRATCH/python-build)"
    echo "  -u: Python user base (default: \$WORK/.local)"
}

pythonver="3.10.11"
install_path="$SCRATCH/python$pythonver"
build_path="$SCRATCH/python-build"
user_base="$WORK/.local"

while getopts "hv:p:b:u:" opt; do
    case $opt in
        h)
            usage
            exit 0
            ;;
        v)
            pythonver="$OPTARG"
            ;;
        p)
            install_path="$OPTARG"
            ;;
        b)
            build_path="$OPTARG"
            ;;
        u)
            user_base="$OPTARG"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            exit 1
            ;;
    esac
done

pymacrover=${pythonver%%.*}
pyminiver=${pythonver#*.} && pyminiver=${pyminiver%.*}
pymicrover=${pythonver##*.}

echo && echo "Installing Python ${pythonver}" && echo
echo "Installation path: ${install_path}"
echo "Build path: ${build_path}"
echo "Python user base: ${user_base}"

# Create necessary directories
mkdir -p "${install_path}"
mkdir -p "${build_path}"
mkdir -p "${user_base}"

# Download and extract Python source
cd "${build_path}"
if [ ! -f Python-${pythonver}.tgz ]; then
    echo && echo "Downloading Python ${pythonver}" && echo
    wget https://www.python.org/ftp/python/${pythonver}/Python-${pythonver}.tgz
fi
tar xzf Python-${pythonver}.tgz
cd Python-${pythonver}

# Configure Python build
echo && echo "Configuring Python build" && echo
./configure --prefix="${install_path}" \
    CC=$TACC_INTEL_BIN/icx \
    CXX=$TACC_INTEL_BIN/icpx \
    CFLAGS="-O3 -xHost -I$TACC_MKL_INC" \
    LDFLAGS="-L$TACC_MKL_LIB -L$TACC_INTEL_LIB" \
    --enable-optimizations \
    --with-ensurepip=install

# Build and install Python
echo && echo "Building and installing Python" && echo
make -j $(nproc)
make install

# Create load.sh file
cat > "${build_path}/load.sh" <<EOF
export PATH=${install_path}/bin:\$PATH
export LD_LIBRARY_PATH=${install_path}/lib:\$LD_LIBRARY_PATH
export PYTHONPATH=${install_path}/lib/python${pymacrover}.${pyminiver}/site-packages:\$PYTHONPATH
export PYTHONUSERBASE=${user_base}
EOF

# Source the load.sh file
source "${build_path}/load.sh"

# Set XDG_CACHE_HOME
export XDG_CACHE_HOME="${build_path}/pipcache"

# Upgrade pip
echo && echo "Upgrading pip" && echo
python3 -m pip install --upgrade pip

echo && echo "Python ${pythonver} installation and setup complete" && echo
echo "To use this Python installation, run: source ${build_path}/load.sh"
