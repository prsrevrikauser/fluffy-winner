
  require "httparty"
  require "nokogiri"
  require "json/pure"
  require 'sqlite3'
  require "byebug"

  # extract price of product from string and return integer value
  # in (str):  "12 510 тг."
  # out (int): 12510
  def extract_price(price_str)
    price_str.split[0..-2].join("").to_i
  end

  # insert unparsed object of page links and return last page number as integer
  # in (Nokogiri obj): Nokogiri<[1, 2, 3, 0, 10, 0]>
  # out (int): 10
  def extract_last_page_num(pages)
    pages.map { |pl| pl.text.strip.to_i }.max
  end

  # if page has pagination return true
  def paginated?(html, selector)
    !html.css(selector).empty?
  end

  # parse a website and return nokogiri object
  def get_parsed_html(url)
    doc = HTTParty::get(url)
    Nokogiri::HTML(doc)
  end

  # clean a string from newlines and empty spaces
  # in (str): "\n       Samsung Galaxy S21 Ultra     \n\r"
  # out (str): "Samsung Galaxy S21 Ultra"
  def strip_text(html, selector)
    html.css(selector).text.strip
  end

  # get full link from a nokogiri object
  # in (Nokogiri obj): Nokogiri<>
  # out (str): "https://www.mechta.kz/product/pylesos-xiaomi-skv4093gl-mi-robot-vacuum-mop-white/"
  def get_product_link(html, selector)
    base_url = "https://www.mechta.kz"
    base_url + html.css(selector).attribute("href").text.strip
  end

  def extract_card_details(card)
    unformatted_price = strip_text(card, "span.aa_std_bigprice")
    {
      title: strip_text(card, "div.aa_std_name a.j_product_link"),
      url: get_product_link(card, "div.aa_std_name a.j_product_link"),
      price: extract_price(unformatted_price),
      code: strip_text(card, "div.only-desktop")
    }
  end

  def get_mechta_json
    file = File::read("/home/bbr/code/ruby/e25_mbt_copy4/fluffy-winner/all_cats.json")
    JSON::parse(file)["mechta"]
  end

  def make_slug(slug_str, page = 1)
    base_url = "https://www.mechta.kz/section/"
    base_url + slug_str + "/?setcity=al&PAGEN_2=" + page.to_s
  end

  # db methods
  def insert_product_qs(table_name, product)
    # prepare sql query string for inserting into db
    "INSERT INTO `#{table_name}` (`title`, `url`, `price`, `code`)
      VALUES (
        '#{product[:title]}',
        '#{product[:url]}',
        #{product[:price]},
        '#{product[:code]}'
      )
    "
  end

  def create_table_qs(table_name)
    # prepare create table query
    "CREATE TABLE IF NOT EXISTS `#{table_name}` (
      id INTEGER PRIMARY KEY,
      title TEXT,
      url TEXT,
      price INT,
      code TEXT
    )"
  end

  # main method
  def scrape(db_name)
    # extract categories for mechta from json file
    data = get_mechta_json

    # save extracted details to items hash
    items = Hash.new

    # go through each big category
    data.each do |category, sub_categories|
      puts "* processing: " + category + "..."
      
      # go through each sub category, ie: pylesosy
      sub_categories.each do |sub_category, slugs|
        puts "* * processing: " + sub_category + "..."

        # insert subcategory name into items hash and make it new array
        items[sub_category] = Array.new
        
        # iterate through each slug string
        # ie. in: ["kofevarki", "kofemashiny-mfg"]
        slugs.each do |slug|
          page_num = 1

          # make a website url for parsing
          parse_url = make_slug(slug)

          # get parsed html of a website; store in html var
          html = get_parsed_html(parse_url)

          # get last page number from parsed html page
          extracted_last_page_num = extract_last_page_num(html.css("div.modern-page-navigation a"))
          # set last page number according to parsed site
          last_page_num = extracted_last_page_num.nil? ? 1 : extracted_last_page_num

          # get number of products per page, ie: 36
          items_per_page = html.css("div.aa_sectiontov").count

          if items_per_page < 36 || last_page_num == 1
            # get cards from page and save it as an array
            cards = html.css("div.aa_sectiontov")

            # ux string
            puts "* * * parsing: " + parse_url + "..."
            
            # iterate through every card and save details
            cards.each do |card|
              item = extract_card_details(card)
              items[sub_category] << item
            end

            # wait for two seconds before sending a request to website
            sleep(1)
          else
            # if there are more than one page per slug,
            # go through every page and get details
            while page_num <= last_page_num
              parse_url = make_slug(slug, page_num)
              html = get_parsed_html(parse_url)

              # extract cards from parsed html
              cards = html.css("div.aa_sectiontov")

              # ux string
              puts "* * * parsing: " + parse_url + "..."

              # iterate through cards, save them
              cards.each do |card|
                item = extract_card_details(card)
                items[sub_category] << item
              end

              # wait for two seconds before sending a request to website
              sleep(1)

              page_num += 1
            end # while statement
          end # else statement
        end # slugs.each statement

        # ux string
        puts "* * * successfully parsed '#{items[sub_category].count}' items into array '#{sub_category}'!"

        # SAVING details to the db!
        begin
          shop_name = "mechta"
          table_name = "#{shop_name}_#{sub_category}"
          # db_name = shop_name + "_db.db"

          # ux string
          puts "* * processing database '#{db_name}'..."

          # connect or create db
          db = SQLite3::Database.new(db_name)

          # ux string
          puts "* * * creating table '#{table_name}'..."

          # prepare create table query string
          query = create_table_qs(table_name)
          # execute create table query
          db.execute query

          # ux string
          puts "* * * successfully created table '#{table_name}'!"

          # interate through every subcategory product and
          # insert them into db
          items[sub_category].each do |product|
            # make insert product query string
            query = insert_product_qs(table_name, product)
            # insert current product into db
            db.execute query

            # wait for a 1/8 before each insertion
            sleep(0.01)

            # ux string
            puts "* * * * successfully inserted '#{product[:title]}' into '#{table_name}'!"
          end

          # ux string
          puts "* * * * successfully inserted all '#{sub_category}' from '#{shop_name}' into '#{table_name}'!"

          # free items hash
          items.clear

        rescue SQLite3::Exception => e 
            puts "Exception occurred."
            puts e
        ensure
            db.close if db
        end
      end
    end
  end

  # RUN
  scrape ARGV.first
