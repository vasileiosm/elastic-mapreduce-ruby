#
# Copyright 2011-2013 Amazon.com, Inc. or its affiliates.  All Rights Reserved.

require 'credentials'
require 'aws/ec2'
require 'aws/core/response'

class Ec2ClientWrapper
  attr_accessor :commands, :logger, :options

  RETRIABLE_EXCEPTIONS = [AWS::Core::Client::NetworkError, AWS::EC2::Errors::ServerError]

  def initialize(commands, logger)
    @commands = commands
    @logger = logger
    @options = commands.global_options
    @config = AWS.config(getConfig)
    @client = AWS::EC2.new(:config => @config).client
    @retries = 3
  end

  def getConfig
    endpoint = EmrConfig.ec2_endpoint(@options[:region], @options[:suffix])
    region = @options[:region]
    uri = URI.parse(endpoint)
    config={
      :ec2_endpoint =>  uri.host,
      :ec2_port => uri.port,
      :use_ssl => true,
      :ssl_ca_file => File.join(File.dirname(__FILE__), "cacert.pem"),
      :ssl_ca_path => File.dirname(__FILE__),
      :ssl_verify_peer => false,
      :ec2_region => region,
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

  def is_error_response(response)
    response != nil && response.key?('Error')
  end

  def raise_on_error(response)
    if is_error_response(response) then
      raise RuntimeError, response["Error"].inspect
    end
    return response
  end

  def call_with_retry(retry_count, backoff=5, &block)
    begin
      result = block.call
    rescue *RETRIABLE_EXCEPTIONS => e
      warn e.message
      if retry_count > 0
        warn "Retrying in #{backoff} seconds..."
        sleep backoff
        result = call_with_retry(retry_count-1, backoff*2, &block)
      else
        raise e
      end
    rescue Exception => ex
      raise RuntimeError, ex.message
    end
    result
  end

  def allocate_address()
    logger.trace "AllocateAddress()"
    result = call_with_retry(@retries) {
      @client.allocate_address()
    }
    logger.trace result.inspect
    return raise_on_error(result)
  end

  def associate_address(instance_id, public_ip)
    logger.trace "AssociateAddress('InstanceId' => #{instance_id.inspect}, 'PublicIp' => #{public_ip.inspect})"
    result = call_with_retry(@retries) {
      @client.associate_address(:instance_id => instance_id.to_s, :public_ip => public_ip.to_s)
    }
    logger.trace result.inspect
    return raise_on_error(result)
  end

  #TODO: Add stubs for all other Ec2 WS operations here, see http://s3.amazonaws.com/ec2-downloads/2010-11-15.ec2.wsdl

end

