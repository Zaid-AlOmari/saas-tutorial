ENV=${1:-dev}
echo "Removing stack..."
DEPLOYMENT_NAMESPACE=app
docker stack rm $DEPLOYMENT_NAMESPACE
limit=15

echo "Waiting for stack to be removed..."
until [ -z "$(docker service ls --filter label=com.docker.stack.namespace=$DEPLOYMENT_NAMESPACE -q)" ] || [ "$limit" -lt 0 ]; do
  sleep 2
  limit="$((limit-1))"
done
limit=15;
until [ -z "$(docker network ls --filter label=com.docker.stack.namespace=$DEPLOYMENT_NAMESPACE -q)" ] || [ "$limit" -lt 0 ]; do
  sleep 2;
  limit="$((limit-1))";
done

token="$(cat ~/.npmrc | grep app)"
if [ "$1" = "dev" ]
then
  echo "Building development image ..."
  docker build . -f dev.Dockerfile -t saas:local --build-arg NPM_TOKEN="${token}"
else
  echo "Building production image ..."  
  docker build . -f Dockerfile -t saas:local --build-arg NPM_TOKEN="${token}"
fi

echo "Deploying stack"
docker stack deploy $DEPLOYMENT_NAMESPACE --compose-file docker-compose.yml --resolve-image always

limit=15
while [ "$limit" -gt 0 ]
do
  echo "Configuring the MongoDB ReplicaSet...";
  mongoId=$(docker ps -aq -f name=saas-mongodb);
  text=$(docker exec $mongoId mongo --eval '''rsconf={_id:"rs0",members:[{_id:0,host:"saas-mongodb:27017",priority:1.0}]};rs.initiate(rsconf);rs.reconfig(rsconf,{force:true});rs.isMaster();''');
  if [[ $text == *"\"ismaster\" : true"* ]]; then
    echo "[DONE]: MongoDB Configured";
    break;
  else
    echo "[WARN]: Trying to Configure MongoDB";
  fi
  limit="$((limit-1))";
  sleep 2
done

docker service logs app_saas -f