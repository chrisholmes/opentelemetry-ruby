require 'opentelemetry-sdk'
require 'socket'

module OpenTelemetry
  module Resource
    module Detectors
      # Aws Ec2 contains detect class method for determining aws environment resource attributes
      module AwsEcs
        extend self
        CONTAINER_ID_LENGTH = 64
        CGROUP_FILE_PATH = '/proc/self/cgroup'

        def detect(cgroup_file_path: CGROUP_FILE_PATH )
          OpenTelemetry::SDK::Resources::Resource.create(resource_attributes(cgroup_file_path))
        end

        def resource_attributes(cgroup_file_path)
          return {} if ENV['ECS_CONTAINER_METADATA_URI_V4'].nil? && ENV['ECS_CONTAINER_METADATA_URI'].nil?

          attributes = {
            OpenTelemetry::SemanticConventions::Resource::CLOUD_PROVIDER => 'aws',
            OpenTelemetry::SemanticConventions::Resource::CLOUD_PLATFORM => 'aws_ecs',
            OpenTelemetry::SemanticConventions::Resource::CONTAINER_NAME => Socket.gethostname
          }

          attributes.merge(cgroup_file_attributes(cgroup_file_path))
                    .reject { |_k, v| v.nil? || v.empty? }
        end

        def cgroup_file_attributes(cgroup_file_path)
          { OpenTelemetry::SemanticConventions::Resource::CONTAINER_ID => container_id(cgroup_file_path) }
        end

        def container_id(cgroup_file_path)
          File.readlines(cgroup_file_path, chomp: true).each do |line|
            return line[-CONTAINER_ID_LENGTH, CONTAINER_ID_LENGTH] if line.length > CONTAINER_ID_LENGTH
          end
          nil
        rescue Errno::ENOENT
          nil
        end
      end
    end
  end
end
