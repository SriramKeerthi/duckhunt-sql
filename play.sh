mkdir -p data
echo Setting up the game, this may take a few seconds...
DOCKER_CONTAINER_ID=$(docker run -d \
    --name duckhunt-sql \
	-e POSTGRES_PASSWORD=duckhunt \
	-e PGDATA=/var/lib/postgresql/data/pgdata \
	-v ./data:/var/lib/postgresql/data \
    -v ./sql:/docker-entrypoint-initdb.d \
    -v ./config/.psqlrc:/root/.psqlrc \
	postgres:16-alpine) > /dev/null
timeout 90s bash -c "until docker exec $DOCKER_CONTAINER_ID pg_isready ; do sleep 0.5 ; done" > /dev/null
sleep 5
clear
docker exec -it $DOCKER_CONTAINER_ID psql -U postgres -d duckhunt -t
docker stop $DOCKER_CONTAINER_ID > /dev/null
docker rm $DOCKER_CONTAINER_ID > /dev/null
echo Cleanup complete
