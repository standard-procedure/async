# frozen_string_literal: true

require "concurrent/array"
require "concurrent/mvar"
require "concurrent/immutable_struct"

module StandardProcedure::Async
  module Actor
    def self.included base
      base.class_eval do
        extend ClassMethods

        def initialize *args
          super
          @_messages = Concurrent::Array.new
        end
      end
    end

    module ClassMethods
      def async name, &implementation
        name = name.to_sym
        implementation_name = :"_#{name}"

        define_method name.to_sym do |*args, &block|
          _add_message_to_queue(implementation_name, *args, &block)
        end

        define_method implementation_name do |*args, &block|
          implementation.call(*args, &block)
        end
      end
    end

    private

    attr_reader :_messages

    def _add_message_to_queue name, *args, &block
      message = Message.new(self, name, args, block, Concurrent::MVar.new)
      _messages << message
      _perform_messages if _messages.count == 1
      message
    end

    def _perform_messages
      StandardProcedure::Async.promises.future do
        while (message = _messages.shift)
          message.call
        end
      end
    end

    class Message < Concurrent::ImmutableStruct.new(:target, :name, :args, :block, :result)
      def value
        result.take
      end

      def call
        result.put target.send(name, *args, &block)
      end
    end
  end
end
