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
    out "Write project root, directory path from your proyect (default source):" 5
    read option
    if [ -z $option ]; then
        set_dotenv PROJECT_ROOT "../source"
    else
        set_dotenv PROJECT_ROOT "../$option"
    fi
    out "Write vhost (default symfony.local):" 5
    read option
    if [ -z $option ]; then
        set_dotenv VHOST "jefe.local"
    else
        set_dotenv VHOST $option
    fi
    out "Write database name (default symfony):" 5
    read option
    if [ -z $option ]; then
        set_dotenv DB_NAME "symfony"
    else
        set_dotenv DB_NAME $option
    fi
    out "Write database username (default symfony):" 5
    read option
    if [ -z $option ]; then
        set_dotenv DB_USERNAME "symfony"
    else
        set_dotenv DB_USERNAME $option
    fi
    out "Write database password (default password):" 5
    read option
    if [ -z $option ]; then
        set_dotenv DB_PASSWORD "password"
    else
        set_dotenv DB_PASSWORD $option
    fi
    out "Database root password is password" 3
    set_dotenv DB_ROOT_PASSWORD "password"
    out "phpMyAdmin url: localhost:8080" 3
    set_dotenv PHPMYADMIN_PORT "8080"
    # Set nginx port to 80
    set_dotenv NGINX_PORT "80"
}

backup() {
    echo 'Not implemented'
}

dump() {
    echo 'Not implemented'
}

importdb() {
    echo 'Not implemented'
}

resetdb() {
    echo 'Not implemented'
}

migrate() {
    echo 'Not implemented'
}

composer_install() {
    e=$1
    if [ -z "${e}" ]; then
        e="docker"
    fi
    if [[ "$e" == "docker" ]]; then
        load_dotenv
        docker exec -it ${project_name}_php bash -c 'composer install'
    else
        load_settings_env $e
        ssh ${user}@${host} -p $port "cd ${public_dir}/; composer install"
    fi
}

composer_update() {
    e=$1
    if [ -z "${e}" ]; then
        e="docker"
    fi
    if [[ "$e" == "docker" ]]; then
        load_dotenv
        docker exec -it ${project_name}_php bash -c 'composer update'
    else
        load_settings_env $e
        ssh ${user}@${host} -p $port "cd ${public_dir}/; composer update"
    fi
}
