#!/bin/bash

if [ -z $1 ]; then
  echo "Please, pass in a shop name to parse."
  echo "Available options: alser, fora, mechta, sulpak, evrika"
  echo "Pass in 'all' to parse all available shops."
  
  exit 1
else
  shop=$1
  now=$(date +%Y%m%d_%H%M%S)
  db_base_name="/home/bbr/code/ruby/e25_mbt_copy4/fluffy-winner/_data/competitors_data_${now}"
  db_comparison_base_name="/home/bbr/code/ruby/e25_mbt_copy4/fluffy-winner/_data/c/comparison_data_${now}"

  case $shop in
  
  "alser")
    db_name="${db_base_name}_alser.db"
    ruby /home/bbr/code/ruby/e25_mbt_copy4/fluffy-winner/alser/main.rb $db_name
    ;;
  
  "fora")
    db_name="${db_base_name}_fora.db"
    ruby /home/bbr/code/ruby/e25_mbt_copy4/fluffy-winner/fora/main.rb $db_name
    ;;
  
  "mechta")
    db_name="${db_base_name}_mechta.db"
    ruby /home/bbr/code/ruby/e25_mbt_copy4/fluffy-winner/mechta/main.rb $db_name
    ;;
  
  "sulpak")
    db_name="${db_base_name}_sulpak.db"
    ruby /home/bbr/code/ruby/e25_mbt_copy4/fluffy-winner/sulpak/main.rb $db_name
    ;;
  
  "evrika")
    db_name="${db_base_name}_evrika.db"
    ruby /home/bbr/code/ruby/e25_mbt_copy4/fluffy-winner/evrika/main.rb $db_name
    ;;

  "all")
    db_name="${db_base_name}_all.db"
    db_comparison_name="${db_comparison_base_name}_all.db"

    # parse sites
    ruby /home/bbr/code/ruby/e25_mbt_copy4/fluffy-winner/evrika/main.rb $db_name
    ruby /home/bbr/code/ruby/e25_mbt_copy4/fluffy-winner/alser/main.rb $db_name
    ruby /home/bbr/code/ruby/e25_mbt_copy4/fluffy-winner/fora/main.rb $db_name
    ruby /home/bbr/code/ruby/e25_mbt_copy4/fluffy-winner/mechta/main.rb $db_name
    ruby /home/bbr/code/ruby/e25_mbt_copy4/fluffy-winner/sulpak/main.rb $db_name

    # compare data
    ruby /home/bbr/code/ruby/e25_mbt_copy4/fluffy-winner/price_comparison/main.rb $db_name $db_comparison_name

    # convert db to excel
    curl -F files[]="${db_comparison_base_name}" "https://www.rebasedata.com/api/v1/convert?outputFormat=xlsx" -o "${db_comparison_base_name}.zip"
    ;;

  esac
  
  exit 1
fi
