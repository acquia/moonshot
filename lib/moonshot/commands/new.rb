# frozen_string_literal: true

module Moonshot
  module Commands
    class New < Moonshot::Command
      self.usage = 'new [options]'
      self.description = 'Creates a new Moonshot project.'

      DEFAULT_DIRECTORY = File.join(__dir__, '..', '..', 'default').freeze

      def execute
        warn 'Looks like your project is already set up!'
      end

      class << self
        def run!(application_name)
          @application_name = application_name

          create_project_dir
          copy_defaults
          fill_moonfile
          print_success_message
        end

        private

        def create_project_dir
          raise "Directory '#{@application_name}' already exists!" \
            if Dir.exist?(project_path)

          Dir.mkdir(project_path)
        end

        def project_path
          @project_path ||= File.join(Dir.pwd, @application_name)
        end

        def copy_defaults
          target_path = File.join(DEFAULT_DIRECTORY.dup, '.')
          FileUtils.cp_r(target_path, project_path)
        end

        def fill_moonfile
          File.open(File.join(project_path, 'Moonfile.rb'), 'w') { |f| f.write generate_moonfile }
        end

        def generate_moonfile
          <<-EOF
Moonshot.config do |m|
  m.app_name             = '#{@application_name}'
  m.artifact_repository  = S3Bucket.new('<your_bucket>')
  m.build_mechanism      = Script.new('bin/build.sh')
  m.deployment_mechanism = CodeDeploy.new(asg: 'AutoScalingGroup')
end
          EOF
        end

        def print_success_message
          warn <<-EOF
Your application is configured, the following changes have been made
to your project directory:

  * Created Moonfile.rb, where you can configure your project.
  * Created moonshot/plugins, where you can place custom Ruby code
    to add hooks to core Moonshot actions (create, update, delete, etc.)
  * Created moonshot/cli_extensions, where you can place custom Ruby
    code to add your own project-specific commands to Moonshot.
  * Created moonshot/template.yml, where you can build your
    CloudFormation template.

You will also need to ensure your Amazon account is configured for
CodeDeploy by creating a role that allows deployments.

See: http://moonshot.readthedocs.io/en/latest/mechanisms/deployment/
          EOF
        end
      end
    end
  end
end
