#!/bin/bash

DIR=/docker-entrypoint.d

if [[ -d "$DIR" ]]
then
  echo "Found docker-entrypoint dir, running scrips in dir"
  /bin/run-parts --verbose --regex '\.(sh|rb)$' "$DIR"
fi

exec gosu "$@"
