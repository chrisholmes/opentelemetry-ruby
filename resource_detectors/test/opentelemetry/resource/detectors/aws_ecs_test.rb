
# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require 'opentelemetry/resource/detectors/aws_ecs'

describe OpenTelemetry::Resource::Detectors::AwsEcs do
  let(:detector) { OpenTelemetry::Resource::Detectors::AwsEcs }

  describe '.detect' do
    let(:cgroup_content) do
      'dummy\n11:devices:/ecs/bbc36dd0-5ee0-4007-ba96-c590e0b278d2/' + container_id;
    end
    let(:container_id) {
      '386a1920640799b5bf5a39bd94e489e5159a88677d96ca822ce7c433ff350163';
    }
    let(:detected_resource) do
      Tempfile.open('cgroup') do |temp_cgroup_file|
        temp_cgroup_file.write(cgroup_content)
        temp_cgroup_file.rewind
        detector.detect(cgroup_file_path: temp_cgroup_file.path) 
      end
    end
    let(:detected_resource_attributes) { detected_resource.attribute_enumerator.to_h }
    let(:expected_resource_attributes) { {} }

    it 'returns an empty resource' do
      _(detected_resource).must_be_instance_of(OpenTelemetry::SDK::Resources::Resource)
      _(detected_resource_attributes).must_equal(expected_resource_attributes)
    end

    describe 'when in a aws Ecs environment' do
      let(:env_stub) do
        {
          'ECS_CONTAINER_METADATA_URI_V4' => 'some-value'
        }
      end

      before do
        Socket.stub(:gethostname, 'my-hostname') do
          ENV.stub(:[], ->(key) { env_stub[key] }) { detected_resource }
        end
      end

      let(:expected_resource_attributes) do
        {
          'cloud.provider' => 'aws',
          'cloud.platform' => 'aws_ecs',
          'container.name' => 'my-hostname',
          'container.id' => container_id
        }
      end

      it 'returns a resource with ecs attributes' do
        _(detected_resource).must_be_instance_of(OpenTelemetry::SDK::Resources::Resource)
        _(detected_resource_attributes).must_equal(expected_resource_attributes)
      end

      describe 'when container.id is not in cgroup' do
        let(:cgroup_content) do
          '13:pids:/\n' + '12:hugetlb:/\n' + '11:net_prio:/'
        end

        it 'returns a resource without that value' do
          _(detected_resource).must_be_instance_of(OpenTelemetry::SDK::Resources::Resource)
          _(detected_resource_attributes.key?('container.id')).must_equal(false)
        end
      end

      describe 'when container.id is not in cgroup' do
        let(:cgroup_content) do
          '13:pids:/\n' + '12:hugetlb:/\n' + '11:net_prio:/'
        end

        it 'returns a resource without that value' do
          _(detected_resource).must_be_instance_of(OpenTelemetry::SDK::Resources::Resource)
          _(detected_resource_attributes.key?('container.id')).must_equal(false)
        end
      end

      describe 'when there is not a cgroup file' do
        let(:detected_resource) { detector.detect(cgroup_file_path: '/tmp/a/path/that/will/not/exist') }

        it 'returns a resource without that value' do
          _(detected_resource).must_be_instance_of(OpenTelemetry::SDK::Resources::Resource)
          _(detected_resource_attributes.key?('container.id')).must_equal(false)
        end
      end

      describe 'when a value is nil' do
        let(:function_name) { nil }

        it 'returns a resource without that value' do
          _(detected_resource).must_be_instance_of(OpenTelemetry::SDK::Resources::Resource)
          _(detected_resource_attributes.key?('faas.name')).must_equal(false)
        end
      end

      describe 'when a value is empty string' do
        let(:function_name) { '' }

        it 'returns a resource without that value' do
          _(detected_resource).must_be_instance_of(OpenTelemetry::SDK::Resources::Resource)
          _(detected_resource_attributes.key?('faas.name')).must_equal(false)
        end
      end
    end
  end
end
