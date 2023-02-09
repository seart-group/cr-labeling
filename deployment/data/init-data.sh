#!/bin/bash

set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -c "\COPY label(name) FROM '/docker-entrypoint-initdb.d/label.txt';"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -c "\COPY reviewer(name) FROM '/docker-entrypoint-initdb.d/reviewer.txt';"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -c "\COPY instance(task, work, category, input_code, input_nl, output, target) FROM '/docker-entrypoint-initdb.d/instance.csv' HEADER DELIMITER ',' QUOTE '\"' CSV;"