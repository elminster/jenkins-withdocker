# Jenkins CI with Docker binaries installed

Added postfix install and config to container to allow relay to an external smtp server. Jenkins can then point mail to its own mailserver.

Configure ARGs in Dockerfile, env file in docker-compose or use --build-arg on command line to configure postfix.



