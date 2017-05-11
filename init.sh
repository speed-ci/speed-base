#!/bin/bash
set -e

printstep() {
    # 36 is blue
    echo -e "\033[36m\n== ${1} \033[37m \n"
}
printmainstep() {
   # 35 is purple
   echo -e "\033[35m\n== ${1} \033[37m \n"
}
printinfo () {
    # 32 is green
    echo -e "\033[32m==== INFO : ${1} \033[37m"
}
printwarn () {
    # 33 is yellow
    echo -e "\033[33m==== ATTENTION : ${1} \033[37m"
}
printerror () {
    # 31 is red
    echo -e "\033[31m==== ERREUR : ${1} \033[37m"
}

init_env () {
    CONF_DIR=/conf/
    if [ -d $CONF_DIR ]; then
        source $CONF_DIR/.env
    fi
    APP_DIR=/usr/src/app/
    if [ ! -d $APP_DIR ]; then
        printerror "Impossible de trouver le dossier du code source de l'application $APP_DIR sur le runner"
        exit 1
    fi    
    if [[ -z $GITLAB_TOKEN ]]; then
        printerror "La variable d'environnement GITLAB_TOKEN n'est pas renseignée, sortie..."
        exit 1
    fi
    if [[ -z $ARTIFACTORY_URL ]]; then
        printerror "La variable d'environnement ARTIFACTORY_URL n'est pas renseignée, sortie..."
        exit 1
    else
        ARTIFACTORY_DOCKER_REGISTRY=${ARTIFACTORY_DOCKER_REGISTRY:-"docker-$ARTIFACTORY_URL"}    
    fi    
    if [[ -z $ARTIFACTORY_USER ]]; then
        printerror "La variable d'environnement ARTIFACTORY_USER n'est pas renseignée, sortie..."
        exit 1
    fi
    if [[ -z $ARTIFACTORY_PASSWORD ]]; then
        printerror "La variable d'environnement ARTIFACTORY_PASSWORD n'est pas renseignée, sortie..."
        exit 1
    fi
    
    ls -l /usr/src/
    
    REPO_URL=$(git config --get remote.origin.url | sed 's/\.git//g' | sed 's/\/\/.*:.*@/\/\//g')
    GITLAB_URL=`echo $REPO_URL | grep -o 'https\?://[^/]\+/'`
    GITLAB_API_URL="$GITLAB_URL/api/v4"
    PROJECT_NAME=${REPO_URL##*/}
    PROJECT_NAMESPACE_URL=${REPO_URL%/$PROJECT_NAME}
    PROJECT_NAMESPACE=${PROJECT_NAMESPACE_URL##*/}
}

check_docker_env () {
    DOCKERFILE=${DOCKERFILE:-"Dockerfile"}
    if [[ ! -f $DOCKERFILE ]];then
        printerror "Le fichier $DOCKERFILE n’est pas présent, il doit se trouver à la racine du projet"
        exit 1
    fi
    DOCKER_SOCKET="/var/run/docker.sock"
    if [[ ! -e $DOCKER_SOCKET ]];then
        printerror "La socket docker $DOCKER_SOCKET n’est pas présente, elle doit être montée au docker run"
        exit 1
    fi    
}
