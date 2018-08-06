require_relative 'box'

module VagrantMutate
  module Box
    class Bhyve < Box
      def initialize(env, name, version, dir)
        super
        @provider_name    = 'bhyve'
        @supported_input  = true
        @supported_output = true
        @image_format     = 'raw'
        @prefix_default   = 'disk'
        @suffix_default   = '.img'
        @suffixes         = /img$/
      end

      # TODO

    end
  end
end
