#
# One-line to manually stop all running containers if needed
#
docker stop `docker ps -aq` && docker rm `docker ps -aq`
