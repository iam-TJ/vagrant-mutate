require 'fileutils'
require 'shellwords'

module VagrantMutate
  module Converter
    class Converter
      def self.create(env, input_box, output_box, force_virtio='false')
      case output_box.provider_name
        when 'bhyve'
          require_relative 'bhyve'
          Bhyve.new(env, input_box, output_box)
        when 'kvm'
          require_relative 'kvm'
          Kvm.new(env, input_box, output_box)
        when 'libvirt'
          require_relative 'libvirt'
          Libvirt.new(env, input_box, output_box, force_virtio)
        else
          fail Errors::ProviderNotSupported, provider: output_box.provider_name, direction: 'output'
        end
      end

      def initialize(env, input_box, output_box, force_virtio='false')
        @env = env
        @input_box  = input_box
        @output_box = output_box
        @force_virtio = force_virtio
        @logger = Log4r::Logger.new('vagrant::mutate')
        @pathnames = []
      end

      def convert
        if @input_box.provider_name == @output_box.provider_name
          fail Errors::ProvidersMatch
        end

        @env.ui.info "Converting #{@input_box.name} from #{@input_box.provider_name} "\
          "to #{@output_box.provider_name}."
        in_lambda = @input_box.image_name('input')
        out_lambda = @output_box.image_name('output')
        until (image_name_tmp = in_lambda.call) == nil do
          @pathnames += [[image_name_tmp, out_lambda.call ]]
          @logger.debug "@pathnames=#{@pathnames}"  
        end
        for index in 0..@pathnames.length-1 do
          @input_box.verify_format(index)
        end
        write_disk
        write_metadata
        write_vagrantfile
        write_specific_files
      end

      private

      def write_metadata
        metadata = {}
        for index in 0..@pathnames.length-1
          metadata.merge!(generate_metadata(index))
        end
        begin
          File.open(File.join(@output_box.dir, 'metadata.json'), 'w') do |f|
            f.write(JSON.generate(metadata))
          end
        rescue => e
          raise Errors::WriteMetadataFailed, error_message: e.message
        end
        @logger.info 'Wrote metadata'
      end

      def write_vagrantfile
        body = generate_vagrantfile
        begin
          File.open(File.join(@output_box.dir, 'Vagrantfile'), 'w') do |f|
            f.puts('Vagrant.configure("2") do |config|')
            f.puts(body)
            f.puts('end')
          end
        rescue => e
          raise Errors::WriteVagrantfileFailed, error_message: e.message
        end
        @logger.info 'Wrote vagrantfile'
      end

      def write_disk
        if @input_box.image_format == @output_box.image_format
          copy_disk
        else
          convert_disk
        end
      end

      def copy_disk
        fail Errors::PathnamesNotExtracted, error_message: "copy_disk" if @pathnames.length == 0
        @pathnames.each { |file_in, file_out|
        input = file_in.to_s.shellescape
        output = file_out.to_s.shellescape
        @logger.info "Copying #{input} to #{output}"
        begin
          FileUtils.copy_file(input, output)
        rescue => e
          raise Errors::WriteDiskFailed, error_message: e.message
        end
        }
      end

      def convert_disk
        fail Errors::PathnamesNotExtracted, error_message: "convert_disk" if @pathnames.length == 0
        @pathnames.each { |file_in, file_out|
        input_file = file_in.to_s.shellescape
        output_file   = file_out.to_s.shellescape
        output_format = @output_box.image_format

        # p for progress bar
        # S for sparse file
        qemu_options = '-p -S 16k'
        qemu_version = Qemu.qemu_version()
        if qemu_version >= Gem::Version.new('1.1.0')
          if output_format == 'qcow2'
            qemu_options += ' -o compat=1.1'
          end
        end

        command = "qemu-img convert #{qemu_options} -O #{output_format} #{input_file} #{output_file}"
        @logger.info "Running #{command}"
        unless system(command)
          fail Errors::WriteDiskFailed, error_message: "qemu-img exited with status #{$CHILD_STATUS.exitstatus}"
        end
        }
      end
    end
  end
end
