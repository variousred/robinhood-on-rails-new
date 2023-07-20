require 'pry'
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :session_id

    def connect
      self.session_id = find_session_id
    end

    private

    def find_session_id
      if session_id = cookies[Rails.application.config.session_options[:key]]
        session_id
      else
        reject_unauthorized_connection
      end
    end
  end
end
