#!/bin/bash
# Author : Anand pratap singh
# Disclaimer: Some of the repos are third party repos
echo 'welcome to blockchain app generator with your chosen stack'
backend="None"
backend_sub="js"
DockerfileBackEndPort="8080"
front_end="None"
DockerfileUi="Dockerfile"
DockerfileUiVol="/home/node/angular-seed/src"
DockerfileUiPort="5555"
DB='None'
Blockchain='None'
smart_contract_repo='truffle'
declare -A techRepoMap


compose_service=""

createInitialMapForRepos() {

    # external github repos

    #node

    techRepoMap[node_ts]="https://github.com/darknightCoder/node_ts_dockerized_starter.git"
    techRepoMap[node_ts_nspa]="https://github.com/Microsoft/TypeScript-Node-Starter.git"
    techRepoMap[node_js_nspa]="https://github.com/sahat/hackathon-starter.git"
    techRepoMap[node_js]="https://github.com/developit/express-es6-rest-api.git"

    #Golang
    techRepoMap[Golang]="https://github.com/qiangxue/golang-restful-starter-kit.git"

    #front end
    techRepoMap[Angular]="https://github.com/mgechev/angular-seed.git"
    techRepoMap[React]="https://github.com/darknightCoder/react-boilerplate.git"
    techRepoMap[Vue]="https://github.com/nicejade/vue-boilerplate-template.git"

    #blockchain

    techRepoMap[quorum]="https://github.com/ConsenSys/quorum-docker-Nnodes.git"

    # blockchain smart contract developoment setup
    techRepoMap[Ethereum]="https://github.com/darknightCoder/truffle-dockerized-starter.git"
    techRepoMap[quorum]="https://github.com/darknightCoder/truffle-dockerized-starter.git"
    techRepoMap[Hyperledger]="https://github.com/darknightCoder/truffle-dockerized-starter.git"

    
 

    #smart contract development setup


    #external images
    techRepoMap[Mongodb]="mongo:latest"
    techRepoMap[Mongodb_port]=27017
    techRepoMap[Mongodb_url]="mongodb://db"

    techRepoMap[Couchdb]="couchdb"
    techRepoMap[Couchdb_port]=5984
    techRepoMap[postgresql]="postgres"
    techRepoMap[postgresql_port]=5432
    echo ${techRepoMap[Mongodb]}

}

createFinalMap() {
    techRepoMap[api]=${techRepoMap[$backend$backend_sub]}

    techRepoMap[db]=${techRepoMap[$DB]}
    techRepoMap[db_port]=${techRepoMap[${DB}_port]}
    techRepoMap[db_url]=${techRepoMap[${DB}_url]}
    echo ${techRepoMap[db_port]}

    techRepoMap[blockchain]=${techRepoMap[$Blockchain]}

   
    techRepoMap[ui]=${techRepoMap[$front_end]}
    if [ "$front_end" = 'Angular' ]; then
        DockerfileUi="./.docker/Dockerfile_dev"
    fi;
    if [ "$backend$backend_sub" = 'node_js' ]; then
        DockerfileBackEndPort=8080
    fi;
    # pull these images now
    gitPull
}

gitPull() {


  for repo in api ui $smart_contract_repo; do
      echo "==> pulling : $repo repo"
      echo ${techRepoMap[$repo]}
      git clone ${techRepoMap[$repo]} $repo 
  done

  if [ "$Blockchain" = "Ethereum" ]; then
      echo "==> pulling : truffle smart contract repo"
      git clone ${techRepoMap[Ethereum]} truffle
  fi
}

createFabricNetwork() {
   mkdir ~/fabric-dev-servers && cd ~/fabric-dev-servers
   curl -O https://raw.githubusercontent.com/hyperledger/composer-tools/master/packages/fabric-dev-servers/fabric-dev-servers.tar.gz
   tar -xvf fabric-dev-servers.tar.gz
   cd ~/fabric-dev-servers
   ./downloadFabric.sh
}

creatDockerComposeFile() {
    cat > docker-compose.yml <<EOF
version: '3'
services:
  portainer:
      image: portainer/portainer
      ports:
        - "9000:9000"
      command: -H unix:///var/run/docker.sock
      volumes:
        - /var/run/docker.sock:/var/run/docker.sock
        - portainer_data:/data
  api:
    build:
      context: ./api
      dockerfile: Dockerfile
    command: npm start
    environment:
      PORT: 5555
      NODE_ENV: 'PRODUCTION'
      SERVER: ${techRepoMap[db_url]}
      PORT_DB: ${techRepoMap[db_port]}
      BLOCKCHAIN_HOST: http://ganache
      BLOCKCHAIN_PORT: 8545
      JWT_SECRET: 'secret'      
    volumes:
      - './api:/api'
    networks:
      blockchain_network:
    ports:
      - $DockerfileBackEndPort:3000
  ui: 
    build:
      context: ./ui
      dockerfile: $DockerfileUi
    command: npm start
    environment: 
       PORT: 3001  
    volumes: 
      - './ui/src:$DockerfileUiVol'  
    ports:
      - $DockerfileUiPort:3001
    networks:
      blockchain_network:
  db: 
    image: ${techRepoMap[db]}
    volumes:
      - './data:/data'
    ports:
      - ${techRepoMap[db_port]}:${techRepoMap[db_port]}
    networks:
      blockchain_network:                   
EOF

# for ethereum
if [ "$Blockchain" = "Ethereum" ]; then 
cat >> docker-compose.yml <<EOF

  truffle:
    build: ./truffle
    command: migrate --reset
    environment:
      BLOCKCHAIN_HOST: ganache
      BLOCKCHAIN_PORT: 8545
    volumes:
      - ./truffle/truffle.js:/truffle/truffle.js:delegated
      - ./truffle/truffle-config.js:/truffle/truffle-config.js:delegated
      - ./truffle/contracts:/truffle/contracts:delegated
      - ./truffle/migrations:/truffle/migrations:delegated
      - ./truffle/test:/truffle/test:delegated      
      - ./volumes/contracts:/truffle/build/contracts:cached
    logging:
      options:
        max-size: 10m
    networks:
      - blockchain_network         
  ganache:
    image: trufflesuite/ganache-cli:v6.1.8
    command: ganache-cli -m 'candy maple cake sugar pudding cream honey rich smooth crumble sweet treat' -a 10 --networkId 100 --gasPrice 1 --gasLimit 100000000
    ports:
      - 8545:8545
    networks:
      - blockchain_network 
EOF
fi;

# for quorum

if [ "$Blockchain" = "Quorum" ]; then
cat >> docker-compose.yml <<EOF

  node_1:
    image: darknightcoder/quorum:latest
    volumes:
      - '/var/vols/qdata_1:/qdata'
    networks:
      quorum_net:
        ipv4_address: '172.13.0.2'
    ports:
      - 22001:8545
    user: '0:0'
  node_2:
    image: darknightcoder/quorum:latest
    volumes:
      - '/var/vols/qdata_2:/qdata'
    networks:
      quorum_net:
        ipv4_address: '172.13.0.3'
    ports:
      - 22002:8545
    user: '0:0'
  node_3:
    image: darknightcoder/quorum:latest
    volumes:
      - '/var/vols/qdata_3:/qdata'
    networks:
      quorum_net:
        ipv4_address: '172.13.0.4'
    ports:
      - 22003:8545
    user: '0:0'    

EOF
fi;
cat >> docker-compose.yml <<EOF
volumes:
  portainer_data:
networks:
  blockchain_network:
    driver: bridge
EOF

if [ "$Blockchain" = "Quorum" ]; then
cat >> docker-compose.yml <<EOF
  quorum_net:
    driver: bridge
    ipam:
      driver: default
      config:
      - subnet: 172.13.0.0/16
EOF
fi;      
}













# setup starts here
createInitialMapForRepos


PS3='Please select the backend framework: '
options=("Node" "Golang" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Node")
            echo "you chose choice $opt"
            backend="node"
            options_sub=("Typescript" "Javascript")
            select opt in "${options_sub[@]}"
            do 
               case $opt in
                    "Typescript")
                         echo "You have chosen node with Typescript"
                         backend_sub="_ts"
                         break
                         ;;
                    "Javascript")
                         echo "You have chose node with Javascript"
                         backend_sub="_js"
                         break
                         ;;     
                    esac
            done        

            break
            ;;
        "Golang")
            echo "you chose choice $opt"
            backend=$opt
            break
            ;;
        "Quit")
            break
            ;;
        *) echo "invalid option $REPLY";;
    esac
done
PS3='Please select the blockchain platform: '
options_bc=("Ethereum" "Hyperledger" "Quorum")
select opt in "${options_bc[@]}"

do
    case $opt in
        "Ethereum")
            Blockchain=$opt
            echo "you chose $opt"
            echo "we will setup the contract deveopment setup for you and use ganache for deployment"
            break
            ;;
        "Hyperledger")
            Blockchain=$opt
            echo "you chose choice $opt"
            break
            ;;
        "Quorum")
            Blockchain=$opt
            echo "you chose choice $REPLY which is $opt"
            break
            ;;
        "Quit")
            break
            ;;
        *) echo "invalid option $REPLY";;
    esac
done

PS3='Please select the front end framework: '

options_fe=("Angular" "React" "Vue" "Quit")
select opt in "${options_fe[@]}"

do
    case $opt in
        "Angular")
            echo "you chose $opt"
            front_end=$opt
            break;
            ;;
        "React")
            front_end=$opt
            echo "you chose choice $opt"
            break
            ;;
        "Vue")
             front_end=$opt
            echo "you chose choice $REPLY which is $opt"
            break
            ;;
        "Quit")
            break
            ;;
        *) echo "invalid option $REPLY";;
    esac
done

PS3='you wish to have a db? tell us which one: '
options_fe=("Mongodb" "Couchdb" "postgresql" "Quit")
select opt in "${options_fe[@]}"

do
    case $opt in
        "Mongodb")
            DB=$opt
            echo "you chose choice 1"
            break
            ;;
        "Couchdb")
            DB=$opt
            echo "you chose choice 2"
            break
            ;;
        "postgresql")
            DB=$opt
            echo "you chose choice $REPLY which is $opt"
            break
            ;;
        "Quit")
            break
            ;;
        *) echo "invalid option $REPLY";;
    esac
done

echo "thanks thats all the info we need now"
echo "generating the docker-compose.yml for you $backend , $Blockchain ,$front_end ,$DB ..."
compose_service=($backend $Blockchain $DB $front_end);

createFinalMap

# creatDockerComposeFile
creatDockerComposeFile

echo Generated the docker-compose.yml for you,now starting the service for you
if [ "$blockchain" = "Hyperledger" ]; then
createFabricNetwork
fi;
 docker-compose up -d 


