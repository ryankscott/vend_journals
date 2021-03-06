require 'date'
require 'net/http'
require 'json'
require 'time'
require 'sinatra'
require_relative 'create_journals.rb'
require_relative 'create_invoices.rb'


# Routes
get '/sales_totals' do
# matches "GET /sales_totals?tag=foo&date_start=1970-01-01&date_end=1970-01-30"
  tag = params['tag']
  begin
  	date_start = Time.parse(params['date_start'])
  	date_end = Time.parse(params['date_end'])
		# do the outlets
		register_id = $register[params["outlet"]]
  rescue ArgumentError
  	# If we can't parse the time
  	status 400
  end
	# Update the times to ISO8601
  json_data = get_sales_totals_by_tag(tag, register_id, date_start.iso8601, date_end.iso8601)
  # TODO - Constrain this 
  response['Access-Control-Allow-Origin'] = '*'
  return json_data.to_json
end


get '/all_sales_totals' do
# matches "GET /sales_totals&outlet=htg&date_start=1970-01-01&date_end=1970-01-30"
  begin

  	date_start = Time.parse(params['date_start'])
		# Make this the end of the day
  	date_end = Time.parse(params['date_end'])

		# do the outlets
		register_id = $register[params["outlet"]]
  rescue ArgumentError
  	# If we can't parse the time
  	status 400
  end
	# Loop through all the tags we know about
	all_tags_totals = get_sales_totals_by_tag(register_id, date_start.iso8601, date_end.iso8601)

  # TODO - Constrain this
  response['Access-Control-Allow-Origin'] = '*'
  return all_tags_totals.to_json
end
 
post '/invoices' do
  # TODO - do some JSON validation
  content_type :json
  data = JSON.parse(request.body.read)
  create_invoice(Date.today, data)
end
