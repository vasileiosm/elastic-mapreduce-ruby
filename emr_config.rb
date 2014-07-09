#
# Copyright 2011-2013 Amazon.com, Inc. or its affiliates.  All Rights Reserved.

module EmrConfig
    PUBLIC_REGION = "aws"
    GOV_REGION = "aws-gov"
    CN_REGION = "aws-cn"
    PUBLIC_SUFFIX = "amazonaws.com"
    CN_SUFFIX = "amazonaws.com.cn"

    REGION_MAP = {
        "us-east-1" => [PUBLIC_REGION, PUBLIC_SUFFIX],
        "us-west-1" => [PUBLIC_REGION, PUBLIC_SUFFIX],
        "us-west-2" => [PUBLIC_REGION, PUBLIC_SUFFIX],
        "eu-west-1" => [PUBLIC_REGION, PUBLIC_SUFFIX],
        "ap-southeast-1" => [PUBLIC_REGION, PUBLIC_SUFFIX],
        "ap-southeast-2" => [PUBLIC_REGION, PUBLIC_SUFFIX],
        "ap-northeast-1" => [PUBLIC_REGION, PUBLIC_SUFFIX],
        "sa-east-1" => [PUBLIC_REGION, PUBLIC_SUFFIX],
        "us-gov-west-1" => [GOV_REGION, PUBLIC_SUFFIX],
        "cn-north-1" => [CN_REGION, CN_SUFFIX]
    }

    EMR_DEFAULT_REGION = "us-east-1"

    def self.ec2_endpoint(region, suffix)
      return get_service_endpoint("ec2", region, suffix)
    end

    def self.is_ec2_sigv2(region)
      return REGION_MAP.has_key?(region) && (REGION_MAP[region][0] == EmrConfig::PUBLIC_REGION || REGION_MAP[region][0] == EmrConfig::GOV_REGION)
    end

    def self.iam_endpoint(region, suffix)
      return get_service_endpoint("iam", region, suffix)
    end

    def self.get_service_principal(service, suffix)
      return "#{service}.#{suffix}"
    end

    def self.get_service_endpoint(servicename, region, suffix)
      if REGION_MAP.has_key?(region) && REGION_MAP[region][0] == PUBLIC_REGION
        return "#{servicename}.#{suffix}"
      else
        return "#{servicename}.#{region}.#{suffix}"
      end
    end

    def self.emr_endpoint(region, emr_endpoint)
      suffix = get_suffix(region, emr_endpoint)
      region = get_region(region, emr_endpoint)
      return "https://elasticmapreduce.#{region}.#{suffix}"
    end

    def self.is_debugging_supported(region)
      return REGION_MAP[region][0] == PUBLIC_REGION
    end

    def self.get_region(region, emr_endpoint)
      if region == nil
        region = get_region_from_endpoint(emr_endpoint)
      end
      return region
    end
 
    def self.get_suffix(region, endpoint)
      if REGION_MAP.has_key?(region)
        return REGION_MAP[region][1]
      else 
        return get_suffix_from_endpoint(endpoint)
      end
    end

    def self.get_suffix_from_endpoint(endpoint)
      suffix_match = get_regex_match_from_endpoint(endpoint)
      if suffix_match != nil && suffix_match.length >= 3
        suffix = suffix_match[3]
      else
        suffix = EmrConfig::PUBLIC_SUFFIX
      end
      return suffix
    end

    def self.get_region_from_endpoint(endpoint)
      region_match = get_regex_match_from_endpoint(endpoint)
      if region_match != nil && region_match.length > 2 && region_match[2] != nil
        region = region_match[2]
      else
        region = EmrConfig::EMR_DEFAULT_REGION
      end
      return region
    end

    def self.get_regex_match_from_endpoint(endpoint)
      if endpoint == nil
        return nil
      end
      regex_match = endpoint.match("(https://)([^.]+).elasticmapreduce.(.*)")
      # Supports 'elasticmapreduce.{region}.' and '{region}.elasticmapreduce.'
      if (regex_match.nil?)
        regex_match = endpoint.match("(https://elasticmapreduce).([^.]+).(.*)")
      end
      return regex_match
    end
end
