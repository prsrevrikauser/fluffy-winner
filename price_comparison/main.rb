
  require "sqlite3"
  require "json/pure"
  require "fuzzystringmatch"
  require "byebug"

  $path_to_db = ARGV.first
  $path_to_comparison_db = ARGV.last
  $path_to_json = "./all_cats.json"

  # byebug

  # in: String[] path to json file
  # out: Hash{} hash from json
  def parse_json_to_hash(path_to_json)
    file = File::read(path_to_json)
    JSON::parse(file)
  end

  # out: Array[] with shop names
  def get_shop_names(exclude = "evrika")
    parse_json_to_hash($path_to_json).keys.reject { |shop| shop == exclude  }
  end

  # out: Array[] all categories from json as flattened array
  def get_categories
    categories = []

    data = parse_json_to_hash($path_to_json)["evrika"]
    data.each { |_c, sub_cat| categories << sub_cat.keys }

    categories.flatten
  end

  # in: String"evrika"
  # out: Array[] of all table names with shop prefix
  def get_table_names(shop_name)
    categories = get_categories
    categories.map { |cat| "#{shop_name}_#{cat}" }
  end

  def extract_category_from_table(table_name)
    true_category = table_name

    first_underscore_index = table_name.index("_")
    true_category = table_name[first_underscore_index + 1..-1]

    true_category
  end

  # in_shop_name: String"fora"
  # in_category: String"evrika_pylesosy"
  # out: String"fora_pylesosy"
  def get_single_table_name(shop_name, category)
    true_category = category
    
    if category.include?("_")
      true_category = extract_category_from_table(category)
    end

    "#{shop_name}_#{true_category}"
  end

  # in: String"" a string of ascii and nonascii chars
  # out: String"" a string cut from all nonascii chars from beginning of str
  def clean_nonascii(str)
    ascii_str = str.gsub(/[^\w\s-]/, "").strip
    first_nonoascii_char_index = str =~ /[0-9A-Za-z]/
    str[first_nonoascii_char_index..-1]
  end

  # in_title: String"" name of a product
  # in_rows: Hash{} all rows from a specific table in db
  # out: Array[] of 2 elements, best match title and price
  def get_best_match(title, rows)
    # initialize default best match distance
    best_match_distance = 0
    
    best_match_title = ""
    best_match_price = 0

    clean_title = clean_nonascii(title.downcase)

    # Jaro Winkler object in pure ruby
    jw = FuzzyStringMatch::JaroWinkler.create :pure

    rows.each do |row|
      clean_product_title = clean_nonascii(row["title"].downcase)

      distance = jw.getDistance(clean_title, clean_product_title)

      if distance > best_match_distance
        best_match_distance = distance
        best_match_title = row["title"]
        best_match_price = row["price"]
      end
    end

    if best_match_distance < 0.94
      return [best_match_title, 0]
    end

    [best_match_title, best_match_price]
  end

  # in: String"" a name of the product
  # out: Array[] brand name and model name as array
  def get_brand_model(title)
    clean_str = clean_nonascii(title).split
    [clean_str.first, clean_str[1..-1].join(" ")]
  end

  # in_shop_names: Array[] of shop names from which to extract prices
  # in_table_name: String"" to get rows of specific category from db
  # in_title: String"" a title to compare in db
  # out: Hash{} of shop name and its match price, 0 if not match found for shop
  def get_match_prices_from_shops(shop_names, category, title)
    
    # hash to store prices for shops, return val
    prices = {}
    
    shop_names.each do |shop_name|

      # get single table name depending on what product category we are 
      # iterating through and which shop it belongs to
      table_name = get_single_table_name(shop_name, category)

      # get all rows from database for a specific shop_table
      rows = db_get_rows("title, price", table_name)

      # get best match as an array of 2 elements, ex.: [title, price]
      best_match = get_best_match(title, rows)

      # save best match values to price hash
      prices[shop_name] = best_match.last

    end

    prices
  end

  # in_fields: String"title, price"
  # in_table: String"alser_pylesosy"
  # out: Array[] with rows
  def db_get_rows(fields, table)
    rows = []

    begin
      db = SQLite3::Database.open $path_to_db
      db.results_as_hash = true
  
      statement = db.prepare "SELECT #{fields} FROM `#{table}`"
      results = statement.execute

      results.each { |row| rows.push(row) }
  
      # statement = db.prepare "SELECT name FROM `sqlite_master` WHERE type='table'"
      # result = statement.execute
  
    rescue SQLite3::Exception => exception
      puts "Exception occurred."
      puts exception
    ensure
      statement.close if statement
      db.close if db
    end

    rows
  end

  def db_store_product_prices(product_prices, shop_names, category)

    # create query string for shop names and sttributes
    shop_names_query = "evrika TEXT,"
    shop_names.sort.each do |shop_name|
      shop_names_query += "#{shop_name} TEXT,"
    end

    # create query string for shop names as insert column header
    columns_query = ""
    shop_names.sort.each { |sn| columns_query += "`#{sn}`," }

    begin
      db = SQLite3::Database.open $path_to_comparison_db
  
      # create table 'category' if it doesn't exist
      db.execute "CREATE TABLE IF NOT EXISTS `#{category}` (
        id INTEGER PRIMARY KEY,
        brand TEXT,
        model TEXT,
        #{shop_names_query.chop}
      )"

      # insert compared prices into db
      product_prices.each do |price|
        
        price_query = ""
        sorted_shop_price = price["shops"].sort_by { |k, _v| k }
        sorted_shop_price.each do |shop_price|
          unless shop_price[0] == "evrika"
            price_query += "" + shop_price[1].to_s + ","
          end
        end

        execution_qs = "INSERT INTO `#{category}` (`brand`, `model`, `evrika`, #{columns_query.chop}) VALUES (
          '#{get_brand_model(price["title"])[0]}', '#{get_brand_model(price["title"])[1]}', #{price["shops"]["evrika"]}, #{price_query.chop})"

        db.execute execution_qs
      end

    rescue SQLite3::Exception => exception
      puts "Exception occurred."
      puts exception
    ensure
      db.close if db
    end
    
    nil
  end

  def mtp

    # main array to store price hashes for every product
    prices = []

    # make and get all table names
    evrika_table_names = get_table_names("evrika")
    # get all shop names from json as array
    shop_names = get_shop_names

    evrika_table_names.each do |evrika_table_name|
      evrika_rows = db_get_rows("title, price", evrika_table_name)

      # store prices for products
      product_prices = []
      evrika_price = 0

      # iterate through rows of data in (ex.:) alser_pylesosy
      evrika_rows.each do |product|
        evrika_price = product["price"]
        evrika_title = product["title"]

        # hash to store price details for different shops
        # ex.: { "title": "Blahblahblah", "shops": { "alser": 25000, "fora": 23900 } }
        price = {
          "title" => evrika_title,
          "shops" => { "evrika" => evrika_price }
        }

        # get prices for specific product from all shops available in the db
        shop_prices = get_match_prices_from_shops(shop_names, evrika_table_name, evrika_title)

        # merge prices from other shops with evrika prices
        price["shops"].merge!(shop_prices)

        # append price for a specific product from different shops to overall product_prices array
        product_prices << price
      end

      db_store_product_prices(
        product_prices,
        shop_names,
        extract_category_from_table(evrika_table_name)
      )

      # byebug
    end

    nil
  end

  mtp
