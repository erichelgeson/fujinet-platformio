#!/bin/bash

# a simple interface to pio so I don't have to remember all the args it needs
# args can be combined, e.g. '-cbxufm' and in any order.
# switches with values must be specified separately.
# typical usage:
#   ./build.sh -h           # display help for this script!
#   ./build.sh -c           # clean
#   ./build.sh -bx          # build, but don't output the dependency graph spam
#   ./build.sh -m           # monitor device
#   ./build.sh -ux          # upload image, no spam in build
#   ./build.sh -fx          # upload file system, no spam in build

RUN_BUILD=0
ENV_NAME=""
DO_CLEAN=0
SHOW_GRAPH=0
SHOW_MONITOR=0
TARGET_NAME=""
PC_TARGET=""
DEBUG_PC_BUILD=1
UPLOAD_IMAGE=0
UPLOAD_FS=0
DEV_MODE=0
ZIP_MODE=0
AUTOCLEAN=1

# This beast finds the directory the build.sh script is in, no matter where it's run from
# which should be the root of the project
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

function show_help {
  echo "Usage: $(basename $0) [-b|-e ENV|-c|-m|-t TARGET|-z|-p TARGET|-g|-h]"
  echo "   -b       # run build"
  echo "   -c       # run clean before build"
  echo "   -d       # add dev flag to build"
  echo "   -e ENV   # use specific environment"
  echo "   -f       # upload filesystem (webUI etc)"
  echo "   -g       # do NOT use debug for PC build, i.e. default is debug build"
  echo "   -m       # run monitor after build"
  echo "   -n       # do not autoclean"
  echo "   -t TGT   # run target task (default of none means do build, but -b must be specified"
  echo "   -p TGT   # perform PC build instead of ESP, for given target (e.g. APPLE|ATARI)"
  echo "   -u       # upload image (device code)"
  echo "   -z       # build flashable zip"
  echo "   -h       # this help"
  exit 1
}

if [ $# -eq 0 ] ; then
  show_help
fi

while getopts ":bcde:fmnp:t:uxzh" flag
do
  case "$flag" in
    b) RUN_BUILD=1 ;;
    c) DO_CLEAN=1 ;;
    d) DEV_MODE=1 ;;
    e) ENV_NAME=${OPTARG} ;;
    f) UPLOAD_FS=1 ;;
    g) DEBUG_PC_BUILD=0 ;;
    m) SHOW_MONITOR=1 ;;
    n) AUTOCLEAN=0 ;;
    p) PC_TARGET=${OPTARG} ;;
    t) TARGET_NAME=${OPTARG} ;;
    u) UPLOAD_IMAGE=1 ;;
    z) ZIP_MODE=1 ;;
    h) show_help ;;
    *) show_help ;;
  esac
done
shift $((OPTIND - 1))

# remove any AUTOADD option left from previous run, and delete the generated backup file
sed -i.bu '/# AUTOADD/d' platformio.ini
rm 2>/dev/null platformio.ini.bu

##############################################################
# ZIP MODE for building firmware zip file.
# This is Separate from the main build, and if chosen exits after running
if [ ${ZIP_MODE} -eq 1 ] ; then
  # find line with post:build_firmwarezip.py and add before it the option uncommented
  sed -i.bu '/^;[ ]*post:build_firmwarezip.py/i\
    post:build_firmwarezip.py # AUTOADD
' platformio.ini
  pio run -t clean -t buildfs
  pio run --disable-auto-clean
  sed -i.bu '/# AUTOADD/d' platformio.ini
  rm 2>/dev/null platformio.ini.bu
  exit 0
fi

##############################################################
# PC BUILD using cmake
if [ ! -z "$PC_TARGET" ] ; then
  echo "PC Build Mode"
  if [ ! -d "$SCRIPT_DIR/build" ] ; then
    echo "ERROR: Could not find build dir to run cmake in"
    exit 1
  fi
  if [ $DO_CLEAN -eq 1 ] ; then
    echo "Removing old build artifacts"
    rm -rf $SCRIPT_DIR/build/*
    rm $SCRIPT_DIR/build/.ninja* 2>/dev/null
  fi
  cd $SCRIPT_DIR/build
  if [ $DEBUG_PC_BUILD -eq 1 ] ; then
    cmake .. -DFUJINET_TARGET=$PC_TARGET -DCMAKE_BUILD_TYPE=Debug
  else
    cmake .. -DFUJINET_TARGET=$PC_TARGET
  fi
  if [ $? -ne 0 ] ; then
    echo "Error running initial cmake. Aborting"
    exit 1
  fi
  # check if all the required python modules are installed
  python -c "import importlib.util, sys; sys.exit(0 if all(importlib.util.find_spec(mod.strip()) for mod in open('${SCRIPT_DIR}/python_modules.txt')) else 1)"
  if [ $? -eq 1 ] ; then
    echo "At least one of the required python modules is missing"
    sh ${SCRIPT_DIR}/install_python_modules.sh
  fi

  cmake --build .
  if [ $? -ne 0 ] ; then
    echo "Error running actual cmake build. Aborting"
    exit 1
  fi
  cmake --build . --target dist
  if [ $? -ne 0 ] ; then
    echo "Error running cmake distribution. Aborting"
    exit 1
  fi
  echo "Built PC version in build/dist folder"
  exit 0
fi


##############################################################
# NORMAL BUILD MODES USING pio

ENV_ARG=""
if [ -n "${ENV_NAME}" ] ; then
  ENV_ARG="-e ${ENV_NAME}"
fi

TARGET_ARG=""
if [ -n "${TARGET_NAME}" ] ; then
  TARGET_ARG="-t ${TARGET_NAME}"
fi

DEV_MODE_ARG=""
if [ ${DEV_MODE} -eq 1 ]; then
  DEV_MODE_ARG="-a dev"
fi

if [ ${DO_CLEAN} -eq 1 ] ; then
  pio run -t clean ${ENV_ARG}
fi

AUTOCLEAN_ARG=""
if [ ${AUTOCLEAN} -eq 0 ] ; then
  AUTOCLEAN_ARG="--disable-auto-clean"
fi

if [ ${RUN_BUILD} -eq 1 ] ; then
  pio run ${DEV_MODE_ARG} $ENV_ARG $TARGET_ARG $AUTOCLEAN_ARG 2>&1
fi

if [ ${UPLOAD_FS} -eq 1 ]; then
  pio run ${DEV_MODE_ARG} -t uploadfs 2>&1
fi

if [ ${UPLOAD_IMAGE} -eq 1 ]; then
  pio run ${DEV_MODE_ARG} -t upload 2>&1
fi

if [ ${SHOW_MONITOR} -eq 1 ]; then
  pio device monitor 2>&1
fi
