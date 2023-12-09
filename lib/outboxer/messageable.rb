module Outboxer
  module Messageable
    def self.included(base)
      base.extend ClassMethods

      base.has_outboxer_message
    end

    module ClassMethods
      def has_outboxer_message(
        dependent: nil,
        class_name: 'Outboxer::Models::Message',
        as: :outboxer_messageable
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
