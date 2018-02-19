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


init_artifactory_env () {
    
    CONF_DIR=/conf/
    if [ -d $CONF_DIR ]; then
        source $CONF_DIR/.env
    fi
    if [[ -z $ARTIFACTORY_URL ]]; then
        printerror "La variable d'environnement ARTIFACTORY_URL doit être renseignée au lancement du container  (ex: -e ARTIFACTORY_URL=https://artifactory.sln.nc)"
        exit 1
    else
        if [[ $ARTIFACTORY_URL != https://* ]]; then ARTIFACTORY_URL="https://$ARTIFACTORY_URL"; fi
        ARTIFACTORY_FQDN=${ARTIFACTORY_URL##*/}
        ARTIFACTORY_DOCKER_REGISTRY=${ARTIFACTORY_DOCKER_REGISTRY:-"docker-$ARTIFACTORY_FQDN"}    
    fi    
    if [[ -z $ARTIFACTORY_USER ]]; then
        printerror "La variable d'environnement ARTIFACTORY_USER doit être renseignée au lancement du container  (ex: -e ARTIFACTORY_USER=prenom.nom)"
        exit 1
    fi
    if [[ -z $ARTIFACTORY_PASSWORD ]]; then
        printerror "La variable d'environnement ARTIFACTORY_PASSWORD doit être renseignée au lancement du container  (ex: -e ARTIFACTORY_PASSWORD=XXXXXXXX)"
        exit 1
    fi
}

init_git_env () {
    
    APP_DIR=/srv/speed
    if [[ ! "$(git rev-parse --is-inside-work-tree)" ]]; then 
        printerror "Le répertoire git de l'application doit être monté et associé au volume $APP_DIR du container (ex: -v \$(pwd):/srv/speed)"
        exit 1
    fi

    REMOTE_ORIGIN_URL=$(git config --get remote.origin.url)
    if [[ -z $REMOTE_ORIGIN_URL ]]; then
        printerror "Le projet git doit disposer d'une remote origin url pour pouvoir extraire les nom et namespace du projet (commande: git config add origin <url>)"
        exit 1
    fi    
    if [[ $REMOTE_ORIGIN_URL == git@* ]]; then REPO_URL=$(echo $REMOTE_ORIGIN_URL | sed 's/\.git//g' | sed 's/:/\//g' | sed 's/git@/https:\/\//g'); fi
    if [[ $REMOTE_ORIGIN_URL == https://* ]]; then REPO_URL=$(echo $REMOTE_ORIGIN_URL | sed 's/\.git//g' | sed 's/\/\/.*@/\/\//g'); fi
    PROJECT_NAME=${REPO_URL##*/}
    PROJECT_NAMESPACE_URL=${REPO_URL%/$PROJECT_NAME}
    PROJECT_NAMESPACE=${PROJECT_NAMESPACE_URL##*/}
    
    if [[ -z $BRANCH_NAME ]]; then
        if [[ ! $(git status | grep "Initial commit")  ]]; then
            BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
        fi
        BRANCH_NAME=${BRANCH_NAME:-"master"}
    fi
}

init_env () {
    
    init_artifactory_env
    init_git_env
}

int_gitlab_api_env () {
    if [[ -z $GITLAB_TOKEN ]]; then
        printerror "La variable d'environnement GITLAB_TOKEN doit être renseignée au lancement du container (ex: -e GITLAB_TOKEN=XXXXXXXX)"
        exit 1
    fi
    
    GITLAB_URL=`echo $REPO_URL | grep -o 'https\?://[^/]\+/'`
    GITLAB_API_URL="$GITLAB_URL/api/v4"
}

check_docker_env () {
    DOCKERFILE=${DOCKERFILE:-"Dockerfile"}
    if [[ ! -f $DOCKERFILE ]];then
        printerror "Le fichier $DOCKERFILE n’est pas présent, il doit se trouver à la racine du projet"
        exit 1
    fi
    DOCKER_SOCKET="/var/run/docker.sock"
    if [[ ! -e $DOCKER_SOCKET ]];then
        printerror "La socket docker $DOCKER_SOCKET doit être montée au lancement du container (ex: -v /var/run/docker.sock:/var/run/docker.sock)"
        exit 1
    fi
    if ! cat $DOCKERFILE | grep -q $ARTIFACTORY_DOCKER_REGISTRY && ! cat $DOCKERFILE | grep -iq "from[[:blank:]]\+scratch"; then 
        printerror "L'image de base utilisée dans le fichier $DOCKERFILE doit être préfixée par la registry docker artifactory $ARTIFACTORY_DOCKER_REGISTRY"
        exit 1
    fi
}

myCurl() {
    HTTP_RESPONSE=`curl --silent --noproxy '*' --write-out "HTTPSTATUS:%{http_code}" "$@"`
    HTTP_BODY=$(echo $HTTP_RESPONSE | sed -e 's/HTTPSTATUS\:.*//g')
    HTTP_STATUS=$(echo $HTTP_RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    if [[ ! $HTTP_STATUS -eq 200 ]] && [[ ! $HTTP_STATUS -eq 404 ]] && [[ ! $HTTP_STATUS -eq 201 ]]; then
        echo -e "\033[31mError [HTTP status: $HTTP_STATUS] \033[37m" 1>&2
        echo -e "\033[31mError [HTTP body: $HTTP_BODY] \033[37m" 1>&2
        echo "{\"error\"}"
        exit 1
    fi
    echo "$HTTP_BODY"
}
