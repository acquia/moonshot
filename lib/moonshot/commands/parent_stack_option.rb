module Moonshot
  module Commands
    module ParentStackOption
      def parser
        parser = super

        parser.on('-pPARENT_STACK', '--parent=PARENT_STACK',
                  'Parent stack to import parameters from') do |v|
          Moonshot.config.parent_stacks = [v]
        end

        parser.on('--parents a,b,c', Array,
                  'List of parent stacks to import parameters from') do |v|
          Moonshot.config.parent_stacks = v
        end
      end
    end
  end
end
