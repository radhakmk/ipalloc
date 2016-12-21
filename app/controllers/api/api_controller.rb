class Api::ApiController < ApplicationController
  require 'yaml'
  require "ipaddr"
  respond_to :json
  skip_before_action :verify_authenticity_token

  # Service Initialize
  def initialize
    @data = YAML::load_file(Rails.configuration.IPALLOC_DATAPATH)
  end

  # Service to find the device by ip
  def find_device
    results = []
    ip_address = params[:ip]
    @data.each do |val|
      if val["ip_address"] == ip_address
        results << val
      end
    end
    if results.empty?
      respond_with({:error => "Not Found", :ip => ip_address}, status: 404)
    else
      respond_with results, status: 200
    end
  end

  # Service to assign the ip to device (ip uniq based on device name)
  def update_device
    ip_address = params[:ip_address]
    device_name = params[:device_name]
    unless is_ip_valid(ip_address)
      found = false
      @data.each do |val|
        if val["ip_address"] == ip_address && val["device_name"] == device_name
          found = true
          respond_with({:error => "Entry already Found", :ip => ip_address, :device_name => device_name}, status: 409, location: api_assign_ip_url)
        end
      end
      unless found
        new_record = [{"ip_block" => "1.2.0.0/16", "ip_address" => ip_address, "device_name" => device_name}]
        File.open(Rails.configuration.IPALLOC_DATAPATH, 'a') do |h|
          h.write new_record.to_yaml.gsub("---\n", '')
        end
        respond_with({"ip_block" => "1.2.0.0/16", "ip_address" => ip_address, "device_name" => device_name}, status: 201, location: api_assign_ip_url)
      end
    else
      respond_with({:error => "IP Address not in Range", :ip => ip_address, :device_name => device_name}, status: 400, location: api_assign_ip_url)
    end
  end

  # IP range validation
  def is_ip_valid(ip)
    start_range = IPAddr.new("1.2.0.0").to_i
    end_range= IPAddr.new("1.2.255.255").to_i
    valid_ip = IPAddr.new(ip).to_i
    unless (start_range..end_range) === valid_ip
      return true
    end
  end

end
