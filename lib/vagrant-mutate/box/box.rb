require 'shellwords'

module VagrantMutate
  module Box
    class Box
      attr_reader :name, :dir, :version, :provider_name, :supported_input, :supported_output, :image_format, :image_name

      def initialize(env, name, version, dir)
        @env     = env
        @name    = name
        @dir     = dir
        @version = version
        @logger  = Log4r::Logger.new('vagrant::mutate')
        @pathnames = []
      end

      def virtual_size(index)
        extract_from_qemu_info(index, /(\d+) bytes/)
      end

      def verify_format(index)
        format_found = extract_from_qemu_info(index, /file format: (\w+)/)
        unless format_found == @image_format
          @env.ui.warn "Expected input image format to be #{@image_format} but "\
            "it is #{format_found}. Attempting conversion anyway."
        end
      end

      def extract_from_qemu_info(index, expression)
        input_file = @pathnames[index].to_s.shellescape
        info = `qemu-img info #{input_file}`
        @logger.debug "qemu-img info output\n#{info}"
        if info =~ expression
          return Regexp.last_match[1]
        else
          fail Errors::QemuInfoFailed
        end
      end

      # generate an incrementing name on each invocation
      def image_name_output
        # start from 1 so virtualbox doesn't need to over-ride this method
        index = 1
        lambda do
          tmp = @pathnames[index-1] = Pathname.new(@dir).join("#{@prefix_default}#{index}#{@suffix_default}")
          index += 1
          return tmp
        end
      end

      # obtain all the valid names but return only 1 per invocation
      def image_name_input
        index = 0
        @pathnames = Pathname.new(@dir).children.select {|f|
          f.file? && f.to_s.match(@suffixes)
        }  if @pathnames.length == 0
        lambda do
          tmp = @pathnames[index]
          index += 1
          return tmp
        end
      end

      def image_name(type='input')
        if type == 'input'
          return image_name_input
        else
          return image_name_output
        end
      end
   end
  end
end
