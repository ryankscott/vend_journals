require 'date'
require 'net/http'
require 'json'
require 'time'
require 'typhoeus'
require 'sinatra'
require 'pmap'
require 'pp'
require_relative 'dao.rb'
require_relative 'properties.rb'

# TODOs
#  Start doing unit tests :'(
#  Try make things a bit more functional
#  Work out version control?
#  Fix the gnarly SQL
#  SQL escaping
#  SQL materialized view

# Run Sinatra on port 4567
set :port, 4567

$log = Logger.new('vend_reports.log')
$log.level = Logger::DEBUG

# TODO  - find a nicer way of doing this lookup
$register = {
	"101" => "1085ca8b-b764-11e1-8d73-4040782fde00",
	"htg" => "38447b87-9eda-11e1-9ffa-4040dde94e2e"
}

$access_token = nil

# Refreshes the Vend API token
def refresh_token()
	# Get the API details
	properties = Properties.new
	all_properties = properties.get_properties()
	api_details = all_properties["vend_api"]

	# If we fail to get from the application file return out
	if api_details.nil?
	  puts ("Unable to get Vend API details from the application file")
		return nil
	end

	request = Typhoeus::Request.new(
		'https://101howick.vendhq.com/api/1.0/token',
		method: :post,
		params: {
			refresh_token: api_details["refresh_token"],
			client_id: api_details["client_id"],
			client_secret: api_details["client_secret"],
			grant_type: "refresh_token"}
		)
	request.on_complete do |response|
		if response.success?
					$access_token = JSON.parse(response.body)['access_token']
		end
	end
	request.run
end

# Persists products and tags to the database
def save_products_and_tags(product_pages)
  # We get multiple product pages, each of them have products
	if !product_pages.empty?
			product_pages.each do |product_page|
				product_page["products"].each do |product|
			# Try and get the tag otherwise we'll create it
			begin
				tag = Tag.first_or_new({:tag_name => product["tags"]}, {:inserted_at => Time.now})
				tag.save
				$log.info("Saving tag with name  #{product["tags"]}")
			rescue DataObjects::IntegrityError => integrityError
				$log.error("Couldn't get or save tag called #{product["tags"]} #{integrityError}")
			rescue DataMapper::SaveFailureError => saveError
				$log.error("Couldn't save tag called #{product["tags"]} #{saveError}")
			end

			# Try persist the product now
			begin
				db_product = Product.create(
					:product_id => product["id"],
					:handle => product["handle"],
					:name => product["name"],
					:description => product["description"],
					:updated_at => product["updated_at"],
					:inserted_at => Time.now,
					:tag => tag)
					db_product.save
					$log.info("Saving product with name #{product["name"]} , handle #{product["handle"]} and product_id #{product["id"]} and updated at #{product["updated_at"]}")
			rescue DataMapper::SaveFailureError => saveError
				$log.error("Couldn't save product with name #{product["name"]} , handle #{product["handle"]} and product_id #{product["id"]}")
			rescue DataObjects::IntegrityError => integrityError
				$log.error("Couldn't save product with name #{product["name"]} , handle #{product["handle"]} and product_id #{product["id"]}")
			end
		end
	end
	end
end

# Persists sales to the database
def save_sales(sales_pages)
	if !sales_pages.empty?
		sales_pages.each do |sales_page|
			sales_page["register_sales"].each do |register_sale|
		# Save the register sale
		db_sale = nil
		begin
				db_sale = RegisterSale.first_or_create(
				{:register_sale_id => register_sale["id"]},
				{:register_id => register_sale["register_id"],
					:sale_date => register_sale["sale_date"],
					:total_price => register_sale["total_price"],
					:total_tax => register_sale["total_tax"],
					:status => register_sale["status"],
					:inserted_at => Time.now}
				)
				db_sale.save
				$log.info("Saving sale with sale_id #{register_sale["id"]} at #{register_sale["sale_date"]}")
			rescue DataMapper::SaveFailureError => saveError
				$log.error("Couldn't save sale with sale_id #{register_sale['id']} - #{saveError}}")
			rescue DataObjects::IntegrityError => integrityError
				$log.error("Couldn't save sale with sale_id #{register_sale["id"]} - #{integrityError}")
			end

		# Save each register sale products
		register_sale["register_sale_products"].each do |register_sale_product|
			begin
				 # Get the product for this sale_product
					product = Product.first(:product_id => register_sale_product["product_id"])
					# Check if we have a product or not
					if product.nil?
						$log.error("Couldn't find a product with id  #{register_sale_product["id"]}, won't be able to persist sale")
					end

					db_sale_product = RegisterSaleProduct.create(
					  :register_sale_product_id => register_sale_product["id"],
						:quantity => register_sale_product["quantity"],
						:price => register_sale_product["price"],
						:tax => register_sale_product["tax"],
						:price_total => register_sale_product["price_total"],
						:tax_total => register_sale_product["tax_total"],
						:inserted_at => Time.now,
						:product => product,
						:register_sale => db_sale
					)
					db_sale_product.save
					$log.info("Saving sale product with sale_product_id #{register_sale_product["id"]}")
				rescue DataMapper::SaveFailureError => saveError
					$log.error("Couldn't save sale product with sale product id  #{register_sale_product["id"]}, product - #{product}, register_sale - #{db_sale} error - #{saveError}")
				rescue DataObjects::IntegrityError => integrityError
					$log.error("Couldn't save sale product with sale product id  #{register_sale_product["id"]}, product - #{product}, register_sale - #{db_sale} error - #{integrityError}")
				end
			end
		end
	end
	end
end

# Gets the latest checked date for products
def get_last_checked_date_for_products()
	last_checked_date = Product.max(:updated_at)
	if last_checked_date.nil?
		return Time.new(1970,1,1).iso8601
	else
		return last_checked_date
	end
end

# Gets the latest checked date for sales
def get_last_checked_date_for_sales()
	last_checked_date = RegisterSale.max(:sale_date)
	if last_checked_date.nil?
		return Time.new(1970,1,1).iso8601
	else
		return last_checked_date
	end
end

# Gets the number of pages of results from a request
def get_number_of_pages_from_a_request(url, parameters)
	request = Typhoeus::Request.new(
		url,
		method: :get,
		params: parameters,
		headers: {Authorization: "Bearer #{$access_token}"}
	)
	request.on_complete do |response|
		if response.success?
			response_json = JSON.parse(response.body)
			if response_json.has_key?("pagination")
			  	number_of_pages = response_json["pagination"]["pages"]
		  		return number_of_pages
			else
				return nil
			end
		elsif response.timed_out?
			$log.error("Got a time out when getting pages for #{url}")
			return nil
		elsif response.code == 0
			$log.error("Got a bad response when getting pages for #{url}")
			return nil
		else
			$log.error("HTTP request failed when getting pages for #{url}")
			return nil
		end
	end
	request.run
end

# TODO - What happens if we don't get a product, that's super bad :/
# Gets all products from Vend
def get_products(force_get_all)
	# Find the last time we got products
	last_checked_date = get_last_checked_date_for_products()
	# If we've never checked or we want to get them all
	if force_get_all
			last_checked_date = Time.new(1970,1,1).iso8601
	end
	puts "Getting all products since #{last_checked_date}"

	# Get number of pages
	number_of_pages = get_number_of_pages_from_a_request("https://101howick.vendhq.com/api/products", {since: last_checked_date})
	if number_of_pages.nil?
		number_of_pages = 1
	end

	$log.info("Found #{number_of_pages} pages of products since #{last_checked_date}")
	puts "Found #{number_of_pages} pages of products since #{last_checked_date}"

	# Get all of the products 100 pages at a time
	hydra = Typhoeus::Hydra.new(max_concurrency: 100)
	requests = []
	number_of_pages.downto(1) do |page|
		requests.push(
			Typhoeus::Request.new(
				'https://101howick.vendhq.com/api/products',
				method: :get,
				params: {
					order_by: "id",
					page: page,
					since: last_checked_date},
				headers: { Authorization: "Bearer #{$access_token}"}
		))
		$log.info("Requesting page #{page} of #{number_of_pages} for products")
	end
	requests.map{|request|
		hydra.queue(request)
		request}

	hydra.run

	responses = requests.map do |request|
		if request.response.success?
				JSON.parse(request.response.body)
		elsif request.response.timed_out?
			$log.error("Got a time out when getting products, missing page.")
		elsif request.response.code == 0
 			$log.error("Got a bad response when getting products, missing page. Error -  #{request.response.return_message}")
		else
			$log.error("HTTP request failed when getting products, missing page. Error -  #{request.response.code}")
			puts JSON.parse(request.response.body)
		end
	end
	return responses
end

# Gets all sales from an outlet between a date range
def get_sales(force_get_all)
	# Find the last time we got products
	last_checked_date = get_last_checked_date_for_sales()
	# If we've never checked or we want to get them all
	if force_get_all
			last_checked_date = Time.new(1970,1,1).iso8601
	end
	puts "Getting all sales since #{last_checked_date}"

	# Get number of sales pages
	number_of_pages = get_number_of_pages_from_a_request("https://101howick.vendhq.com/api/register_sales", {since: last_checked_date})
	if number_of_pages.nil?
		number_of_pages = 1
	end

	$log.info("Found #{number_of_pages} pages of sales since #{last_checked_date}")
	puts "Found #{number_of_pages} pages of sales since #{last_checked_date}"

	# Request all the pages of sales 100 at a time
	hydra = Typhoeus::Hydra.new(max_concurrency: 100)
	requests = []
	number_of_pages.downto(1) do |page|
		requests.push(
			Typhoeus::Request.new(
				'https://101howick.vendhq.com/api/register_sales',
				method: :get,
				params: {page: page, since: last_checked_date},
				headers: {Authorization: "Bearer #{$access_token}"}
		))
	$log.info("Requesting page #{page} of #{number_of_pages} for sales")
	end
	requests.map{|request|
		hydra.queue(request)
		request}

	hydra.run

	responses = requests.map do |request|
		if request.response.success?
			JSON.parse(request.response.body)
		elsif request.response.timed_out?
			$log.error("Got a time out when getting sales, missing page.")
		elsif request.response.code == 0
 			$log.error("Got a bad response when getting sales, missing page. Error -  #{request.response.return_message}")
		else
			$log.error("HTTP request failed when getting sales, missing page. Error -  #{request.response.code}")
		end
	end
	return responses
end

# Gets all sales totals by tag from a register between a date range
def get_sales_totals_by_tag(register_id, date_start, date_end)
	total = repository(:default).adapter.select("select t.tag_name, SUM(rsp.price_total) as total from register_sale_product rsp inner join register_sale rs on rsp.register_sale_id = rs.id inner join product p on rsp.product_id = p.id inner join tag t on t.id = p.tag_id where rs.sale_date BETWEEN '#{date_start}' and '#{date_end}' and rs.register_id = '#{register_id}' group by t.tag_name")
	return total.map {|x| x.to_h}
end

# Gets all sales totals by tag from a register between a date range
def get_sales_totals_for_tag(tag, register_id, date_start, date_end)
	total = repository(:default).adapter.select("select t.tag_name, SUM(rsp.price_total) as total from register_sale_product rsp inner join register_sale rs on rsp.register_sale_id = rs.id inner join product p on rsp.product_id = p.id inner join tag t on t.id = p.tag_id where rs.sale_date BETWEEN '#{date_start}' and '#{date_end}' and rs.register_id = '#{register_id}' and t.tag_name = '#{tag}' group by t.tag_name")
	return 	total.map {|x| x.to_h}
end

# Get the sales totals for a tag by month for a year
def get_sales_totals_for_tag_month_for_year(tag, register_id, year)
		total = repository(:default).adapter.select("
		SELECT
		  t.tag_name,
		  SUM(rs.total_price) as total,
		  DATE_PART('MONTH', rs.sale_date) as month
		FROM
		  register_sale rs
		INNER JOIN
		  register_sale_product rsp
		ON
		  rsp.register_sale_id = rs.id
		INNER JOIN
		  product p
		ON
		  p.id = rsp.product_id
		INNER JOIN
		  tag t
		ON
		  t.id = p.tag_id
		WHERE
		  DATE_PART('YEAR', rs.sale_date) = '#{year}'
		AND
		  t.tag_name = '#{tag}'
		AND
			rs.register_id = '#{register_id}'
		GROUP BY
		  DATE_PART('MONTH', rs.sale_date),
		  t.tag_name
		ORDER BY
		    DATE_PART('MONTH', rs.sale_date) asc")
		return 	total.map {|x| x.to_h}
end

# Get the sales totals by tag and month for a year
def get_sales_totals_by_tag_month_for_year(register_id, year)
		total = repository(:default).adapter.select("
		SELECT
		  t.tag_name,
		  SUM(rs.total_price) as total,
		  DATE_PART('MONTH', rs.sale_date) as month
		FROM
		  register_sale rs
		INNER JOIN
		  register_sale_product rsp
		ON
		  rsp.register_sale_id = rs.id
		INNER JOIN
		  product p
		ON
		  p.id = rsp.product_id
		INNER JOIN
		  tag t
		ON
		  t.id = p.tag_id
		WHERE
		  DATE_PART('YEAR', rs.sale_date) = '#{year}'
		AND
			rs.register_id = '#{register_id}'
		GROUP BY
		  DATE_PART('MONTH', rs.sale_date),
		  t.tag_name
		ORDER BY
		    DATE_PART('MONTH', rs.sale_date) asc")
		return 	total.map {|x| x.to_h}
end

def get_top_ten_products_by_revenue_for_month(register_id, month, year)
		total = repository(:default).adapter.select("
		SELECT
			p.name,
			SUM(rs.total_price) as total
		FROM
			register_sale rs
		INNER JOIN
			register_sale_product rsp
		ON
			rsp.register_sale_id = rs.id
		INNER JOIN
			product p
		ON
			p.id = rsp.product_id
		WHERE
			DATE_PART('MONTH', rs.sale_date) = '#{month}'
		AND
			DATE_PART('YEAR', rs.sale_date) = '#{year}'
		AND
				rs.register_id = '#{register_id}'
		GROUP BY
			DATE_PART('MONTH', rs.sale_date),
			p.name
		ORDER BY
				total desc
		LIMIT 10")
		return 	total.map {|x| x.to_h}
	end

def get_top_ten_products_by_quantity_for_month(register_id, month)
	total = repository(:default).adapter.select("
	SELECT
		p.name,
		SUM(rsp.quantity) as count
	FROM
		register_sale rs
	INNER JOIN
		register_sale_product rsp
	ON
		rsp.register_sale_id = rs.id
	INNER JOIN
		product p
	ON
		p.id = rsp.product_id
	WHERE
		DATE_PART('MONTH', rs.sale_date) = '#{month}'
	AND
		DATE_PART('YEAR', rs.sale_date) = '#{year}'
	AND
			rs.register_id = '#{register_id}'
	GROUP BY
		DATE_PART('MONTH', rs.sale_date),
		p.name
	ORDER BY
			count desc
	LIMIT 10")
	return 	total.map {|x| x.to_h}
	end

def get_average_sale_price_by_month_for_year(register_id, year)
		total = repository(:default).adapter.select("
		SELECT
		      DATE_PART('MONTH', rs.sale_date),
		      AVG(rs.total_price) as average_sale
		    FROM
		      register_sale rs
		    INNER JOIN
		      register_sale_product rsp
		    ON
		      rsp.register_sale_id = rs.id
		    INNER JOIN
		      product p
		    ON
		      p.id = rsp.product_id
		    WHERE
		      DATE_PART('YEAR', rs.sale_date) = '#{year}'
				AND
						rs.register_id = '#{register_id}'
		    GROUP BY
		      DATE_PART('MONTH', rs.sale_date)
		    ORDER BY
		      DATE_PART('MONTH', rs.sale_date) asc")
		return 	total.map {|x| x.to_h}
		end

# Refresh out API token
refresh_token()

# Schedule this to happen every day
save_products_and_tags(get_products(false))
save_sales(get_sales(false))
