require 'date'
require 'net/http'
require 'json'
require 'time'
require 'typhoeus'
require 'xeroizer'
require_relative 'dao.rb'
require_relative 'properties.rb'



# Get the API details
properties = Properties.new
all_properties = properties.get_properties()
api_details = all_properties["xero_api"]

# If we fail to get from the database return out
if api_details.nil?
  puts ("Unable to get Xero API details from the application file")
end

$client = Xeroizer::PrivateApplication.new(api_details["consumer_key"], api_details["consumer_secret"], api_details["private_key_path"])

def create_invoice(due_date, line_items)
  invoice = $client.Invoice.build({
    :type => "ACCREC",
    :contact => { :name => "Vend Reconciliation" },
    :status => "DRAFT",
    :due_date => due_date,
    :date => Date.today,
    })
    line_items.each do |line_item|
      invoice.add_line_item({
        :description => if line_item["tag_name"].empty? then "No tag" else line_item["tag_name"] end,
        :quantity => 1,
        :unit_amount => line_item["total"].to_f})
      end
      invoice.save
    end
