#
# Copyright 2011-2013 Amazon.com, Inc. or its affiliates.  All Rights Reserved.

require 'credentials'
require 'aws/iam'
require 'aws/core/response'

class IamClientWrapper
  attr_accessor :options, :logger

  RETRIABLE_EXCEPTIONS = [AWS::Core::Client::NetworkError, AWS::EC2::Errors::ServerError]

  def initialize(options, logger)
    @options = options
    @logger = logger
    @config = AWS.config(getConfig)
    @client = AWS::IAM.new(:config => @config).client
  end

  def getConfig
    endpoint = EmrConfig.iam_endpoint(@options[:region], @options[:suffix])
    region = @options[:region]
    uri = URI.parse(endpoint)
    config={
      :iam_endpoint =>  uri.host,
      :iam_port => uri.port,
      :use_ssl => true,
      :ssl_ca_file => File.join(File.dirname(__FILE__), "cacert.pem"),
      :ssl_ca_path => File.dirname(__FILE__),
      :ssl_verify_peer => false,
      :iam_region => region,
      :verbose => (@options[:verbose] != nil),
      :secret_access_key => @options[:aws_secret_key],
      :access_key_id => @options[:aws_access_id],
      :http_read_timeout => 60.0,
      :http_wire_trace => @options[:trace] || false,
      :options => @options[:force] || false
    }
                                                                                                                                                     
    error_if_nil(config[:access_key_id], "Missing access-key")
    error_if_nil(config[:secret_access_key], "Missing secret-key")
                                                                                                                                                               
    config
  end
  
  def error_if_nil(value, message)
    if value == nil then
      raise RuntimeError, message
    end
  end

  def role_exists?(role_name)
    begin
      @client.get_role(:role_name  => role_name)
    rescue AWS::Errors::Base => e
      if e.message.include?("The role with name #{role_name} cannot be found.")
        # No such role.
        return false
      else
        # Some other error: reraise.
        raise e
      end
    end
    return true
  end

  def instance_profile_exists?(instance_profile_name)
    begin
      @client.get_instance_profile(:instance_profile_name => instance_profile_name)
    rescue AWS::Errors::Base => e
      if (e.message.include?("Instance Profile #{instance_profile_name} cannot be found"))
        # No such instance profile
        return false
      else
        # Some other error: reraise.
        raise e
      end
    end
    return true
  end

  def create_instance_profile(instance_profile_name, role_name)
    logger.puts "Creating instance profile #{instance_profile_name}..."
    @client.create_instance_profile(:instance_profile_name => instance_profile_name)

    logger.puts "Attaching role #{role_name} to instance profile #{instance_profile_name}"
    @client.add_role_to_instance_profile(:instance_profile_name => instance_profile_name, :role_name => role_name)
  end

  def create_role(role_name, assume_role_policy, policy)
    logger.puts "Creating role #{role_name}..."
    @client.create_role(:role_name => role_name, :assume_role_policy_document => assume_role_policy)

    logger.puts "Attaching policy ..."
    @client.put_role_policy(:role_name => role_name, :policy_name => role_name, :policy_document => policy)
  end

end

