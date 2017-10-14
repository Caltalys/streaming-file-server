#!/usr/bin/env bash

# debug
#set -x
LOG_LEVEL=info
#LOG_LEVEL=debug

# app info
VERSION=3.0.0
COMPOSE_FILE="docker-compose-${VERSION}.yml"
FILENAME="streaming-file-server-${VERSION}.jar"
ITEMS_SERVICE_FILENAME="file-items-rest-service-${VERSION}.jar"

if [ "'$LOG_LEVEL'" == "'debug'" ]; then
  echo "version                   : $VERSION"
  echo "docker-compose file       : $COMPOSE_FILE"
  echo "application filename      : $FILENAME"
  echo "data-layer application    : $ITEMS_SERVICE_FILENAME"
  echo
fi

# required binaries info
WHICH=$(which which)
RM=$(which rm)
DOCKER_COMPOSE=$(which docker-compose)
PS=$(which ps)
KILL=$(which kill)
GREP=$(which grep)
WGET=$(which wget)
AWK=$(which awk)
MKDIR=$(which mkdir)
BASH_CMD=$(which bash)

# args
ARGS=$#
SCRIPT="$0"
APPLICATION_COMMAND="$1"
FILE_STORAGE_PATH="$2"

if [ "'$LOG_LEVEL'" == "'debug'" ]; then
  echo "ARGS                      : '$ARGS'"
  echo "SCRIPT                    : '$SCRIPT'"
  echo "FILE_STORAGE_PATH         : '$FILE_STORAGE_PATH'"
  echo "APPLICATION_COMMAND       : '$APPLICATION_COMMAND'"
  echo
  echo "using which          from : '$WHICH'"
  echo "using rm             from : '$RM'"
  echo "using docker-compose from : '$DOCKER_COMPOSE'"
  echo "using ps             from : '$PS'"
  echo "using kill           from : '$KILL'"
  echo "using grep           from : '$GREP'"
  echo "using awk            from : '$AWK'"
  echo "using wget           from : '$WGET'"
  echo "using mkdir          from : '$MKDIR'"
  echo "using bash           from : '$BASH_CMD'"
  echo
fi

function FAIL_STOP_WITH_USAGE_FUNC {
    echo "Usage:"
    echo ""
    echo "start     application : $0 start \$PATH_TO_FILE_STORAGE"
    echo "stop      application : $0 stop"
    echo "stop      application : $0 clean \$PATH_TO_FILE_STORAGE"
    echo ""
    echo "note                  : binaries: 'which', 'rm', 'wget', 'docker-compose', 'kill', 'grep', 'awk', 'mkdir' and 'bash' are required"
    exit 1
}

function VALIDATE_INPUTS_FUNC {
  if [ ${ARGS} -eq 0 ]; then
    FAIL_STOP_WITH_USAGE_FUNC
  fi

  if [ ${ARGS} -eq 1 ] && [ "'$APPLICATION_COMMAND'" == "'start'" ]; then
    FAIL_STOP_WITH_USAGE_FUNC
  fi

  if [ ${ARGS} -eq 1 ] && [ "'$APPLICATION_COMMAND'" == "'clean'" ]; then
    FAIL_STOP_WITH_USAGE_FUNC
  fi
}

VALIDATE_INPUTS_FUNC

# docker compose
function GET_COMPOSE_FUNC {
  if [ ! -f "$COMPOSE_FILE" ]; then
    ${WGET} "https://github.com/daggerok/streaming-file-server/releases/download/$VERSION/$COMPOSE_FILE"
  fi
}

function START_DATABASE_FUNC {
  GET_COMPOSE_FUNC

  if [ "'$LOG_LEVEL'" == "'info'" ]; then
    echo "start postgres database"
  fi

  ${DOCKER_COMPOSE} -f ${COMPOSE_FILE} up -d
}

# application
function GET_APPLICATION_FUNC {
  if [ ! -f "$FILENAME" ]; then

    if [ "'$LOG_LEVEL'" == "'info'" ]; then
      echo "download application"
    fi

    ${WGET} "https://github.com/daggerok/streaming-file-server/releases/download/$VERSION/$FILENAME"
    ${WGET} "https://github.com/daggerok/streaming-file-server/releases/download/$VERSION/$ITEMS_SERVICE_FILENAME"
  fi
}

function START_APPLICATION_FUNC {
  GET_COMPOSE_FUNC
  START_DATABASE_FUNC
  GET_APPLICATION_FUNC

  ${BASH_CMD} ${ITEMS_SERVICE_FILENAME}

  ${MKDIR} -p "$FILE_STORAGE_PATH"
  ${BASH_CMD} ${FILENAME} --app.upload.path="$FILE_STORAGE_PATH"
}

if [ "'$APPLICATION_COMMAND'" == "'start'" ]; then
  START_APPLICATION_FUNC
fi

function STOP_APPLICATION_FUNC {
  for F_NAME in ${FILENAME} ${ITEMS_SERVICE_FILENAME}; do
    APPLICATION_PID=$(${PS} waux|${GREP} ${F_NAME}|${GREP} -v 'grep'|${AWK} '{print $2}')

    if [ "'$LOG_LEVEL'" == "'info'" ]; then
      echo "killing application by pid '$APPLICATION_PID' if exists"
    fi

    for P_ID in "$APPLICATION_PID"; do
      if [ "''" != "'$P_ID'" ]; then
        echo "${KILL} -9 $P_ID";
        ${KILL} "-9" ${P_ID}
      fi
    done
  done
}

function STOP_DATABASE_FUNC {
  if [ "'$1'" != "'--download=false'" ]; then
    GET_COMPOSE_FUNC
  fi

  if [ "'$LOG_LEVEL'" == "'info'" ]; then
    echo "stop postgres database"
  fi

  ${DOCKER_COMPOSE} -f ${COMPOSE_FILE} down -v
}

if [ "'$APPLICATION_COMMAND'" == "'stop'" ]; then
  STOP_APPLICATION_FUNC
  STOP_DATABASE_FUNC
  exit 0;
fi

function CLEANUP_FUNC {
  STOP_APPLICATION_FUNC

  if [ "'$LOG_LEVEL'" == "'info'" ]; then
    echo "remove web app file: '$FILENAME'"
  fi

  if [ -f "$FILENAME" ]; then
    ${RM} -rf "$FILENAME"
  fi

  if [ "'$LOG_LEVEL'" == "'info'" ]; then
    echo "remove data-layer app file: '$ITEMS_SERVICE_FILENAME'"
  fi

  if [ -f "$ITEMS_SERVICE_FILENAME" ]; then
    ${RM} -rf "$ITEMS_SERVICE_FILENAME"
  fi

  STOP_DATABASE_FUNC --download=false

  if [ "'$LOG_LEVEL'" == "'info'" ]; then
    echo "remove docker compose file: '$COMPOSE_FILE' if exists"
  fi

  if [ -f "$COMPOSE_FILE" ]; then
    ${RM} -rf "$COMPOSE_FILE"
  fi

  if [ "'$FILE_STORAGE_PATH'" != "''" ]; then
    read -p "Are you sure about removing '$FILE_STORAGE_PATH'? " -n 1 -r
    echo # move to a new line

    if [[ $REPLY =~ ^[Yy]$ ]]; then
      ${RM} -rf ${FILE_STORAGE_PATH}
    fi
  fi
}

if [ "'$APPLICATION_COMMAND'" == "'clean'" ]; then
  CLEANUP_FUNC
  exit 0
fi