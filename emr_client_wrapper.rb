
# Copyright 2011-2013 Amazon.com, Inc. or its affiliates.  All Rights Reserved.

require 'credentials'
require 'aws/emr'
require 'uri'
require 'emr_config'

class EmrClient
  attr_accessor :commands, :logger, :options

  RETRIABLE_EXCEPTIONS = [AWS::Core::Client::NetworkError, AWS::EMR::Errors::ServerError]

  def initialize(commands, logger, client_class)
    @commands = commands
    @logger = logger
    @options = commands.global_options
    @config = AWS.config(getConfig)
    @client = client_class.new(:config => @config).client
    @retries = 3
  end

  def getConfig
    region = @options[:region]
    endpoint = @options[:endpoint] || EmrConfig.emr_endpoint(region, nil)
    uri = URI.parse(endpoint)
    config={
        :emr_endpoint =>  uri.host,
        :emr_port => uri.port,
        :use_ssl => (uri.scheme.downcase =="https"),
        :ssl_ca_file => File.join(File.dirname(__FILE__), "cacert.pem"),
        :ssl_ca_path => File.dirname(__FILE__),
        :ssl_verify_peer => false,
        :emr_region => @options[:region] || EmrConfig.get_region_from_endpoint(endpoint),
        :verbose => (@options[:verbose] != nil),
        :secret_access_key => @options[:aws_secret_key],
        :access_key_id => @options[:aws_access_id],
        :http_read_timeout => 60.0,
        :http_wire_trace => @options[:trace] || false,
        :options => @options[:force] || false,
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

  def is_error_response(response)
    response != nil && response.key?('Error')
  end
  
  def raise_on_error(response)
    if is_error_response(response) then
      raise RuntimeError, response["Error"]["Message"]
    end
    return response
  end
  
  def describe_jobflow_with_id(jobflow_id)
    logger.trace "describe_jobflow_with_id('JobFlowIds' => [ #{jobflow_id} ])"
    result = call_with_retry(@retries) {
        @client.describe_job_flows('JobFlowIds' => [ jobflow_id ], 'DescriptionType' => 'EXTENDED')
    }
    logger.trace result.inspect
    raise_on_error(result)
    if result == nil || result['JobFlows'].size() == 0 then
      raise RuntimeError, "Jobflow with id #{jobflow_id} not found"
    end
    return result['JobFlows'].first
  end

  def add_steps(jobflow_id, steps)
    logger.trace "AddJobFlowSteps('JobFlowId' => #{jobflow_id.inspect}, 'Steps' => #{steps.inspect})"
    result = call_with_retry(@retries) {
        @client.add_job_flow_steps('JobFlowId' => jobflow_id, 'Steps' => steps)
    }
    logger.trace result.inspect
    return raise_on_error(result)
  end

  def run_jobflow(jobflow)
    logger.trace "RunJobFlow(#{jobflow.inspect})"
    result = call_with_retry(@retries) {
        @client.run_job_flow(jobflow)
    }
    logger.trace result.inspect
    return raise_on_error(result)
  end

  def describe_jobflow(options)
    logger.trace "DescribeJobFlows(#{options.inspect})"
    result = call_with_retry(@retries) {
        @client.describe_job_flows(options.merge('DescriptionType' => 'EXTENDED'))
    }
    logger.trace result.inspect
    return raise_on_error(result)
  end

  def set_termination_protection(jobflow_ids, protected)
    logger.trace "SetTerminationProtection('JobFlowIds' => #{jobflow_ids.inspect}, 'TerminationProtected' => #{protected})"
    result = call_with_retry(@retries) {
        @client.set_termination_protection('JobFlowIds' => jobflow_ids, 'TerminationProtected' => protected)
    }
    logger.trace result.inspect
    return raise_on_error(result)
  end

  def set_visible_to_all_users(jobflow_ids, visible)
    logger.trace "SetVisibleToAllUsers('JobFlowIds' => #{jobflow_ids.inspect}, 'VisibleToAllUsers' => #{visible})"
    result = call_with_retry(@retries) {
        @client.set_visible_to_all_users('JobFlowIds' => jobflow_ids, 'VisibleToAllUsers' => visible)
    }
    logger.trace result.inspect
    return raise_on_error(result)
  end

  def terminate_jobflows(jobflow_ids)
    logger.trace "TerminateJobFlows('JobFlowIds' => #{jobflow_ids.inspect})"
    result = call_with_retry(@retries) {
        @client.terminate_job_flows('JobFlowIds' => jobflow_ids)
    }
    logger.trace result.inspect
    return raise_on_error(result)
  end

  def modify_instance_groups(options)
    logger.trace "ModifyInstanceGroups(#{options.inspect})"
    result = call_with_retry(@retries) {
        @client.modify_instance_groups(options)
    }
    logger.trace result.inspect
    return raise_on_error(result)
  end    

  def add_instance_groups(options)
    logger.trace "AddInstanceGroups(#{options.inspect})"
    result = call_with_retry(@retries) {
        @client.add_instance_groups(options)
    }
    logger.trace result.inspect
    return raise_on_error(result)
  end

  # New APIs
  def add_tags(resource_id, tags)
    logger.trace "AddTags( 'ResourceId' => #{resource_id.inspect}, 'Tags' => #{tags.inspect} )"
    result = call_with_retry(@retries) {
        @client.add_tags('ResourceId' => resource_id, 'Tags' => tags)
    }
    logger.trace result.inspect
    return raise_on_error(result)
  end

  def remove_tags(resource_id, tag_keys)
    logger.trace "RemoveTags( 'ResourceId' => #{resource_id.inspect}, 'TagKeys' => #{tag_keys.inspect})"
    result = call_with_retry(@retries) {
        @client.remove_tags('ResourceId' => resource_id, 'TagKeys' => tag_keys)
    }
    logger.trace result.inspect
    return raise_on_error(result)
  end

  def describe_cluster(cluster_id)
    logger.trace "DescribeCluster( 'ClusterId' => #{cluster_id.inspect})"
    result = call_with_retry(@retries) {
        @client.describe_cluster( 'ClusterId' => cluster_id)
    }
    logger.trace result.inspect
    return raise_on_error(result)
  end

  def describe_step(cluster_id, step_id)
    logger.trace "DescribeStep( 'ClusterId' => #{cluster_id.inspect}, 'StepId' => #{step_id.inspect})"
    result = call_with_retry(@retries) {
        @client.describe_step( 'ClusterId' => cluster_id, 'StepId' => step_id)
    }
    logger.trace result.inspect
    return raise_on_error(result)
  end

  def list_bootstrap_actions(cluster_id, marker)
    logger.trace "ListBootstrapActions( 'ClusterId' => #{cluster_id.inspect}, 'Marker' => #{marker.inspect})"
    result = call_with_retry(@retries) {
        @client.list_bootstrap_actions('ClusterId' => cluster_id, 'Marker' => marker)
    }
    logger.trace result.inspect
    return raise_on_error(result)
  end

  def list_clusters(created_after, created_before, cluster_states, marker)
    logger.trace "ListClusters( 'CreatedAfter' => #{created_after.inspect}, 'CreatedBefore' => #{created_before.inspect}, 'ClusterStates' => #{cluster_states.inspect}, 'Marker' => #{marker.inspect})"
    result = call_with_retry(@retries) {
        @client.list_clusters('CreatedAfter' => created_after, 'CreatedBefore' => created_before, 'ClusterStates' => cluster_states, 'Marker' => marker)
    }
    logger.trace result.inspect
    return raise_on_error(result)
  end

  def list_instance_groups(cluster_id, marker)
    logger.trace "ListInstanceGroups('ClusterId' => #{cluster_id.inspect}, 'Marker' => #{marker.inspect})"
    result = call_with_retry(@retries) {
        @client.list_instance_groups('ClusterId' => cluster_id, 'Marker' => marker)
    }
    logger.trace result.inspect
    return raise_on_error(result)
  end

  def list_instances(cluster_id, instance_group_id, instance_group_type, marker)
    logger.trace "ListInstances('ClusterId' => #{cluster_id.inspect}, 'InstanceGroupId' => #{instance_group_id.inspect}, 'InstanceGroupTypes' => #{instance_group_type.inspect}, 'Marker' => #{marker.inspect})"
    result = call_with_retry(@retries) {
        @client.list_instances('ClusterId' => cluster_id, 'InstanceGroupId' => instance_group_id, 'InstanceGroupTypes' => instance_group_type, 'Marker' => marker)
    }
    logger.trace result.inspect
    return raise_on_error(result)
  end

  def list_steps(cluster_id, step_states, marker)
    logger.trace "ListSteps('ClusterId' => #{cluster_id.inspect}, 'StepStates' => #{step_states.inspect}, 'Marker' => #{marker.inspect})"
    result = call_with_retry(@retries) {
        @client.list_steps('ClusterId' => cluster_id, 'StepStates' => step_states, 'Marker' => marker)
    }
    logger.trace result.inspect
    return raise_on_error(result)
  end
end

