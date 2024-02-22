module Outboxer
  module Outboxable
    # The Outboxable module, when included in a class, provides the ability to associate
    # that class with an Outboxer message. This association is set up through a series
    # of class methods defined in the included ClassMethods module.

    def self.included(base)
      base.extend ClassMethods

      base.has_outboxer_message
    end

    module ClassMethods
      def has_outboxer_message(
        dependent: nil,
        class_name: 'Outboxer::Models::Message',
        as: :outboxable
      )
        has_one :outboxer_message,
                dependent: dependent,
                class_name: class_name,
                as: as

        after_create :create_outboxer_message!
      end
    end
  end
end
