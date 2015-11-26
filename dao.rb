require 'rubygems'
require 'data_mapper'
require 'dm-migrations'
require_relative 'properties.rb'

DataMapper::Logger.new($stdout, :error)
DataMapper::Model.raise_on_save_failure = true

# Get the DB details
properties = Properties.new
all_properties = properties.get_properties()
database = all_properties["database"]

# If we fail to get from the application file return out
if database.nil?
  puts ("Unable to get DB details from the application file")
end

# A Postgres connection:
#DataMapper.setup(:default, "postgres://#{database["username"]}:#{database["password"]}@#{database["host"]}/#{database["schema"]}")

# SQLite connection
DataMapper.setup(:default, "sqlite://#{Dir.pwd}/vend_reports.db")

class Product
  include DataMapper::Resource
  property :id,           Serial
  property :product_id,   UUID, :unique => true, :required => true
  property :handle,       String, :length => 100
  property :name,         String, :length => 100
  property :description,  Text
  property :inserted_at,  DateTime
  property :updated_at,   DateTime
  belongs_to :tag
  has n, :register_sale_product, :required => true
  storage_names[:default] = 'product'
end

class Tag
  include DataMapper::Resource
  property :id,           Serial
  property :tag_name,     String, :length => 100, :unique => true, :index => true
  property :inserted_at,  DateTime
  has n, :product, :required => true
  storage_names[:default] = 'tag'
end


class RegisterSale
  include DataMapper::Resource
  property :id, 		            Serial
  property :register_sale_id, 	UUID, :unique => true, :required => true
  property :register_id,        UUID, :required => true
  property :sale_date, 		      DateTime, :required => true, :index => true
  property :total_price,	      Float
  property :total_tax,  	      Float
  property :status,		          String, :length => 100
  property :inserted_at,        DateTime
  has n, :register_sale_product, :required => true
  storage_names[:default] = 'register_sale'
end

class RegisterSaleProduct
  include DataMapper::Resource
  property :id,			      Serial
  property :register_sale_product_id, 	UUID, :unique => true, :required => true
  property :quantity,		  Integer
  property :price,		    Float
  property :tax,		      Float
  property :price_total,	Float, :index => true
  property :tax_total,		Float
  property :inserted_at,  DateTime
  belongs_to :product
  belongs_to :register_sale
  storage_names[:default] = 'register_sale_product'
end

DataMapper.finalize
DataMapper.auto_upgrade!
