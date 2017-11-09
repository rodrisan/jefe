#!/bin/bash
#
# jefe.sh
#

# print text with color
out() {
    #     Num  Colour    #define         R G B
    #     0    black     COLOR_BLACK     0,0,0
    #     1    red       COLOR_RED       1,0,0
    #     2    green     COLOR_GREEN     0,1,0
    #     3    yellow    COLOR_YELLOW    1,1,0
    #     4    blue      COLOR_BLUE      0,0,1
    #     5    magenta   COLOR_MAGENTA   1,0,1
    #     6    cyan      COLOR_CYAN      0,1,1
    #     7    white     COLOR_WHITE     1,1,1
    text=$1
    color=$2
    echo "$(tput setaf $color)$text $(tput sgr 0)"
}

set_dotenv(){
    echo "$1=$2" >> .jefe/.env
}

get_dotenv(){
    echo $( grep "$1" .jefe/.env | sed -e "s/$1=//g" )
}

load_dotenv(){
    project_type=$( get_dotenv "PROJECT_TYPE" )
    project_name=$( get_dotenv "PROJECT_NAME" )
    project_root=$( get_dotenv "PROJECT_ROOT" )
    dbname=$( get_dotenv "DB_NAME" )
    dbuser=$( get_dotenv "DB_USERNAME" )
    dbpassword=$( get_dotenv "DB_PASSWORD" )
    dbhost=$( get_dotenv "DB_HOST" )
}

# read yaml file
parse_yaml() {
    local prefix=$2
    local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
    sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
    awk -F$fs '{
    indent = length($1)/2;
    vname[indent] = $2;
    for (i in vname) {if (i > indent) {delete vname[i]}}
        if (length($3) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
        }
    }'
}

get_yamlenv(){
    echo $( parse_yaml .jefe/settings.yaml | grep "^$1_$2" | sed -e "s/$1_$2=//g" | sed -e "s/\"//g")
}

load_settings_env(){
    # access yaml content
    user=$( get_yamlenv $1 user)
    group=$( get_yamlenv $1 group)
    host=$( get_yamlenv $1 host)
    port=$( get_yamlenv $1 port)
    public_dir=$( get_yamlenv $1 public_dir)
    dbname=$( get_yamlenv $1 dbname)
    dbuser=$( get_yamlenv $1 dbuser)
    dbpassword=$( get_yamlenv $1 dbpassword)
    dbhost=$( get_yamlenv $1 dbhost)
    exclude=$( get_yamlenv $1 exclude)
}

# configure ruby project
configure_project() {
    create_folder_structure
}

# Docker compose var env configuration.
docker_env() {
    out "Docker compose var env configuration." 4
    #     if [[ ! -f ".jefe/.env" ]]; then
    #         cp .jefe/default.env .jefe/.env
    #     fi
    echo "" > .jefe/.env
    set_dotenv PROJECT_TYPE $project_type
    out "Write project name (default docker_$project_type):" 5
    read option
    if [ -z $option ]; then
        set_dotenv PROJECT_NAME docker_$project_type
    else
        set_dotenv PROJECT_NAME $option
    fi
    out "Write project root, directory path from your proyect (default src):" 5
    read option
    if [ -z $option ]; then
        set_dotenv PROJECT_ROOT src
    else
        set_dotenv PROJECT_ROOT $option
    fi
    out "Write database name (default docker):" 5
    read option
    if [ -z $option ]; then
        set_dotenv DB_NAME docker
    else
        set_dotenv DB_NAME $option
    fi
    out "Write database username (default docker):" 5
    read option
    if [ -z $option ]; then
        set_dotenv DB_USER docker
    else
        set_dotenv DB_USER $option
    fi
    out "Write database password (default docker):" 5
    read option
    if [ -z $option ]; then
        set_dotenv DB_PASSWORD docker
    else
        set_dotenv DB_PASSWORD $option
    fi
    out "Write RAILS_ENV var (default development):" 5
    read option
    if [ -z $option ]; then
        set_dotenv RAILS_ENV development
    else
        set_dotenv RAILS_ENV $option
    fi
}

backup() {
    e=$1

    if [ -z "${e}" ]; then
        e="docker"
    fi

    if [[ "$e" == "docker" ]]; then
        load_dotenv
        docker exec -it ${project_name}_rails pg_dump -U ${dbname} ${project_name} > ./db/${project_name}.sql
    else
        load_settings_env $e
        ssh ${user}@${host} -p $port "mkdir -p jefe; pg_dump -U ${dbname} ${project_name} > ./jefe/${project_name}.sql"
    fi
}

resetdb() {
    e=$1
    if [ -z "${e}" ]; then
        e="docker"
    fi

    if [[ "$e" == "docker" ]]; then
        load_dotenv
        docker exec -it ${project_name}_rails bash -c 'export RAILS_ENV=docker;rails db:migrate VERSION=0;rails db:migrate;rails db:seed'
    else
        load_settings_env
        read -p "Are you sure?[Y/n] " -n 1 -r
        echo    # move to a new line
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
            ssh "${user}@${host} 'rails db:migrate VERSION=0;rails db:migrate;rails db:seed'"
        fi
    fi
}

migrate() {
  e=$1
  if [ -z "${e}" ]; then
    e="docker"
  fi

  if [[ "$e" == "docker" ]]; then
    load_dotenv
    docker exec -it ${project_name}_rails bash -c 'export RAILS_ENV=docker;rails db:migrate'
  else
    load_settings_env $e
    ssh ${user}@${host} -p $port "cd ${public_dir}/; ~/.rbenv/shims/rails db:migrate"
  fi
}


bundle_install() {
    e=$1
    if [ -z "${e}" ]; then
        e="docker"
    fi

    if [[ "$e" == "docker" ]]; then
        load_dotenv
        docker exec -it ${project_name}_rails bash -c 'bundle install'
    else
        load_settings_env $e
        ssh ${user}@${host} -p $port "cd ${public_dir}/; ~/.rbenv/shims/bundle install"
    fi
}

bundle_update() {
    e=$1
    if [ -z "${e}" ]; then
        e="docker"
    fi

    if [[ "$e" == "docker" ]]; then
        load_dotenv
        docker exec -it ${project_name}_rails bash -c 'bundle update'
    else
        load_settings_env $e
        ssh ${user}@${host} -p $port "cd ${public_dir}/; ~/.rbenv/shims/bundle update"
    fi
}

deploy() {
    e=$1
    t=$2

    if [ -z "${e}" ]; then
        e="docker"
    fi

    if [ -z "${t}" ]; then
        t="false"
    fi

    load_dotenv
    load_settings_env $e
    excludes=$( echo $exclude | sed -e "s/;/ --exclude=/g" )
    if [ "${t}" == "true" ]; then
        set -x #echo on
        rsync --dry-run -az --force --delete --progress --exclude=$excludes -e "ssh -p${port}" "$project_root/." "${user}@${host}:$public_dir"
    else
        set -x #echo on
        rsync -az --force --delete --progress --exclude=$excludes -e "ssh -p$port" "$project_root/." "${user}@${host}:$public_dir"
    fi
}
