module Moonshot
  # The AlwaysUseDefaultSource will always use the previous value in
  # the stack, or use the default value during stack creation. This is
  # useful if plugins provide the value for a parameter, and we don't
  # want to prompt the user for an override. Of course, overrides from
  # answer files or command-line arguments will always apply.
  class AlwaysUseDefaultSource
    def get(sp)
      unless sp.default?
        raise "Parameter #{sp.name} does not have a default, cannot use AlwaysUseDefaultSource!"
      end

      # Don't do anything, the default will apply on create, and the
      # previous value will be used on update.
    end
  end
end
