require_relative 'box'
require 'shellwords'

module VagrantMutate
  module Box
    class Libvirt < Box
      def initialize(env, name, version, dir)
        super
        @provider_name    = 'libvirt'
        @supported_input  = true
        @supported_output = true
        @image_format     = 'qcow2'
        @mac              = nil
        @prefix_default   = 'box'
        @suffix_default   = '.img'
        @suffixes         = /(qcow|qcow.|img)$/
      end

      # since none of below can be determined from the box
      # we just generate sane values

      def architecture
        'x86_64'
      end

      # kvm prefix is 52:54:00
      def mac_address
        unless @mac
          octets = 3.times.map { rand(255).to_s(16) }
          @mac = "525400#{octets[0]}#{octets[1]}#{octets[2]}"
        end
        @mac
      end

      def cpus
        1
      end

      def memory
        536_870_912
      end

      def disk_interface
        'virtio'
      end
    end
  end
end
