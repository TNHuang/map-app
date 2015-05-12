require 'nokogiri'
require 'open-uri'
require 'geocoder'

class RootController < ApplicationController

	def root
		render :homepage
	end

	def crawl_xml
		url = 'http://www.related.com/feeds/ZillowAvailabilities.xml'
		@locations = extract_location_info(url)
		long_lats = get_long_lats(@locations, true)
		@isXml = true
		@google_static_map_url = get_google_static_map_url(long_lats)

		render :homepage
	end

	def crawl_website
		url = 'http://www.corcoran.com/nyc/Search/Listings?SaleType=Rent&Page='
		@locations = extract_locations_from_website(url)
		long_lats = get_long_lats(@locations)
		@isXml = false
		@google_static_map_url = get_google_static_map_url(long_lats)

		render :homepage
	end

	private

	def extract_locations_from_website(url, pagelimit = 2)
		locations = []
		
		(1..pagelimit).each do |page_num|
			page_url = "#{url}#{page_num}"
			page = open_page(page_url)
			
			page.css('tbody > tr').each do |listing|
				locations.push(listing.attribute('title').text) if listing
			end
		end
		
		locations.uniq 
	end

	def extract_location_info(url)
		#open web crawler
		locations = open_page(url).css("listing > location")
		locations = locations.map do |location|
			#address, city, state, zipcode
			{ 
				address: location.css('streetaddress').text,
				city: location.css('city').text,
				state: location.css('state').text,
				zip: location.css('zip').text,
			}
		end

		locations.uniq
	end

	def get_full_address(address)
		full_address = "#{address[:address]}, #{address[:city]}, #{address[:state]}, #{address[:zip]}"
	end

	def get_long_lats(locations, isXml = false)
		#locaions format are in [ {address: xxx, city: yyy, etc}]
		locations = locations.map {|location| get_full_address(location)} if isXml
		long_lats = []

		locations.each do |address|
			long_lat = Geocoder.search(address)[0]
			sleep 0.1
			long_lats.push(long_lat) unless long_lat.nil?
		end
		long_lats
	end
	
	def get_google_static_map_url(long_lats)
		base_url = "http://maps.google.com/maps/api/staticmap?size=900x600&sensor=false&zoom=4"
		colors = ["red", "blue", "green", "orange", "purple"]
		markers = []
		long_lats.each do |long_lat|
			str = "markers=color:#{colors.sample}|#{long_lat.latitude}%2C#{long_lat.longitude}"
			markers.push(str)
		end

		"#{base_url}&#{markers.join('&')}"
	end

	def open_page(url)
		page = Nokogiri::HTML(open(url))
	end

	def root_params
		params.require(:map).permit(:address)
	end
end
