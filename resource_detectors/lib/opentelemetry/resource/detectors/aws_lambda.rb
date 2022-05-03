require 'opentelemetry-sdk'

module OpenTelemetry
  module Resource
    module Detectors
      # Aws Ec2 contains detect class method for determining aws environment resource attributes
      module AwsLambda
        extend self
        def resource_attributes
          lambda_name = ENV['AWS_LAMBDA_FUNCTION_NAME']
          return {} if lambda_name.nil?

          region = ENV['AWS_REGION']
          function_version = ENV['AWS_LAMBDA_FUNCTION_VERSION']

          {
            OpenTelemetry::SemanticConventions::Resource::CLOUD_PROVIDER => 'aws',
            OpenTelemetry::SemanticConventions::Resource::CLOUD_PLATFORM => 'aws_lambda',
            OpenTelemetry::SemanticConventions::Resource::FAAS_NAME      => lambda_name,
            OpenTelemetry::SemanticConventions::Resource::FAAS_VERSION   => function_version
          }.reject { |_k, v| v.nil? || v.empty? }
        end

        def detect
          OpenTelemetry::SDK::Resources::Resource.create(resource_attributes)
        end
      end
    end
  end
end
