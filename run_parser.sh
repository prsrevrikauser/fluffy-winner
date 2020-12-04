#!/bin/bash

if [ -z $1 ]; then
  echo "Please, pass in a shop name to parse."
  echo "Available options: alser, fora, mechta, sulpak"
  echo "Pass in 'all' to parse all available shops."
  
  exit 1
else
  shop=$1
  now=$(date +%Y%m%d_%H%M%S)
  db_base_name="./_data/competitors_data_for_${now}"

  case $shop in
  
  "alser")
    db_name="${db_base_name}_alser.db"
    ruby ./alser/main.rb $db_name
    ;;
  
  "fora")
    db_name="${db_base_name}_fora.db"
    ruby ./fora/main.rb $db_name
    ;;
  
  "mechta")
    db_name="${db_base_name}_mechta.db"
    ruby ./mechta/main.rb $db_name
    ;;
  
  "sulpak")
    db_name="${db_base_name}_sulpak.db"
    ruby ./sulpak/main.rb $db_name
    ;;
  
  "evrika")
    db_name="${db_base_name}_evrika.db"
    ruby ./evrika/main.rb $db_name
    ;;

  "all")
    db_name="${db_base_name}_all.db"
    ruby ./alser/main.rb $db_name
    ruby ./fora/main.rb $db_name
    ruby ./mechta/main.rb $db_name
    ruby ./sulpak/main.rb $db_name
    ruby ./evrika/main.rb $db_name
    ;;

  esac
  
  exit 1
fi
