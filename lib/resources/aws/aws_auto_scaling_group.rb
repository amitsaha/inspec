require 'uri'

class AwsAutoScalingGroup < Inspec.resource(1)
  name 'aws_auto_scaling_group'
  desc 'Verifies settings for an Auto Scaling Group'
  example "
    describe aws_auto_scaling_group('MyAutoScalingGroup') do
      it { should exist }
      its('min_size') { should be 1}
      its('desired_capacity') { should be 2 }
      its('max_size') { should be 4}
      its('launch_configuration_name') { should eq 'MyLaunchConfiguration'}


      its('vpc_zone_identifier') { should include 'subnet-1234'}
      its('tags') { should include({'key': 'Application', 'value': 'TestApplication', 'resource_type': 'auto-scaling-group', 'resource_id': fixtures['auto_scaling_group_test_name'], 'propagate_at_launch': true}) }

    end
  "
  supports platform: 'aws'

  include AwsSingularResourceMixin
  attr_reader :name, :min_size, :max_size, :desired_capacity, :vpc_zone_identifier, :launch_configuration_name, :tags, :health_check_type

  private

  def validate_params(raw_params)
    validated_params = check_resource_param_names(
      raw_params: raw_params,
      allowed_params: [:name],
      allowed_scalar_name: :name,
      allowed_scalar_type: String,
    )
    if validated_params.empty?
      raise ArgumentError, 'You must provide a name to aws_auto_scaling_group.'
    end
    validated_params
  end

  def fetch_from_api
    aws_response = BackendFactory.create(inspec_runner).get_auto_scaling_group_attributes(auto_scaling_group_names: [@name])
    if aws_response.auto_scaling_groups.length == 1
      @exists = true
      auto_scaling_group = aws_response.auto_scaling_groups[0]

      @name = auto_scaling_group[:auto_scaling_group_name]
      @min_size = auto_scaling_group[:min_size].to_i
      @max_size = auto_scaling_group[:max_size].to_i
      @desired_capacity = auto_scaling_group[:desired_capacity].to_i
      @health_check_type = auto_scaling_group[:health_check_type]

      @vpc_zone_identifier = auto_scaling_group[:vpc_zone_identifier].split(',')
      @launch_configuration_name = auto_scaling_group[:launch_configuration_name]

      @tags = []
      auto_scaling_group[:tags].map { |tag|
        @tags.push({
                     'resource_id': tag.resource_id,
          'resource_type': tag.resource_type,
          'key': tag.key,
          'value': tag.value,
          'propagate_at_launch': tag.propagate_at_launch,
                   })
      }
    else
      @exists = false
    end
  end

  # Uses the SDK API to really talk to AWS
  class Backend
    class AwsClientApi < AwsBackendBase
      BackendFactory.set_default_backend(self)
      self.aws_client_class = Aws::AutoScaling::Client

      def get_auto_scaling_group_attributes(criteria)
        aws_service_client.describe_auto_scaling_groups(criteria)
      end
    end
  end
end
