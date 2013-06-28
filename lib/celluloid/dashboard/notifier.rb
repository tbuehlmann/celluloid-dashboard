module Celluloid
  class Dashboard
    class Notifier
      include Celluloid
      include Celluloid::Notifications

      MAX_NOTIFICATIONS = 100

      def initialize(max_notifications = MAX_NOTIFICATIONS)
        @max_notifications = max_notifications
        @notifications = []
        subscribe //, :process
        Celluloid::Actor[:dashboard_notifier] = Actor.current
      end

      attr_reader :notifications

      def process(topic, *args)
        notification = {
          time: Time.now,
          topic: topic,
          args: args
        }
        
        add(notification)
        Application.notify(notification) if Dashboard.running?
      end

      def clear
        @notifications.clear
      end

      private

      def add(notification)
        if @notifications.size >= @max_notifications
          pops = @notifications.size - @max_notifications + 1
          @notifications.pop(pops)
        end

        @notifications << notification
      end
    end
  end
end
