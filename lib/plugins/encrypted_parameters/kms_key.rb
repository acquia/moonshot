require_relative '../../moonshot/stack.rb'

module Moonshot
  module Plugins
    class EncryptedParameters
      # Class that manages KMS keys in AWS.
      class KmsKey
        attr_reader :arn
        class << self
          def create
            standard_tags = stack_tags
            resp = Aws::KMS::Client.new.create_key({
               tags:  standard_tags, # An array of tags.
              })
            arn = resp.key_metadata.arn
            new(arn)
          end

          def stack_tags
            tags = Moonshot::Stack.make_tags(Moonshot.config)
            tags.map { |tag| { tag_key:  tag[:key], tag_value:  tag[:value] } }
          end
        end

        def initialize(arn)
          @arn = arn
          @kms_client = Aws::KMS::Client.new
        end

        def update
          standard_tags = self.class.stack_tags
          @kms_client.tag_resource({
            key_id: @arn, # arn of the CMK being tagged
            tags: standard_tags, # An array of tags.
          })
        end

        def delete
          @kms_client.schedule_key_deletion(key_id: @arn, pending_window_in_days: 7)
        end
      end
    end
  end
end
