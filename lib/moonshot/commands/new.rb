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
          create_file(parameter_path)
          create_file(template_path)
          fill_moonfile
          print_success_message
        end

        private

        def cwd
          Dir.pwd
        end

        def create_project_dir
          raise "Directory '#{@application_name}' already exists!" \
            if Dir.exist?(project_path)
          Dir.mkdir(project_path)
        end

        def project_path
          @project_path ||= File.join(cwd, @application_name)
        end

        def copy_defaults
          target_path = File.join(DEFAULT_DIRECTORY.dup, '.')
          FileUtils.cp_r(target_path, project_path)
        end

        def create_file(path)
          FileUtils.touch(path)
        end

        def moonfile_path
          File.join(project_path, 'Moonfile.rb')
        end

        def parameter_path
          File.join(cf_dir, 'parameters', "#{@application_name}.yml")
        end

        def template_path
          File.join(cf_dir, "#{@application_name}.json")
        end

        def cf_dir
          File.join(project_path, 'cloud_formation')
        end

        def fill_moonfile
          File.open(moonfile_path, 'w') { |f| f.write generate_moonfile }
        end

        def generate_moonfile
          <<-EOF
            Moonshot.config do |m|
              m.app_name = '#{@application_name}'
              m.artifact_repository = S3Bucket.new('<your_bucket>')
              m.build_mechanism = Script.new('bin/build.sh')
              m.deployment_mechanism = CodeDeploy.new(asg: 'AutoScalingGroup')
            end
        	EOF
        end

        def print_success_message
          warn 'Your application is configured, the following changes have '\
               'been made to your project directory:'
          warn ''
          warn '- Created a Moonfile.rb where you can configure your project.'
          warn '- Created moonshot/plugins where you can add hooks to core '\
               'Moonshot actions.'
          warn '- Created moonshot/cli_extensions where you can create '\
               'project-specific commands.'
          warn ''
          warn 'You will also need to ensure your Amazon account is configured'\
               ' for CodeDeploy, by creating a role that allows deployments. '\
               'See: http://moonshot.readthedocs.io/en/latest/mechanisms/'\
               'deployment/'
        end
      end
    end
  end
end
