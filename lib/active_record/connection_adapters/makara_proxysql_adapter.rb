require 'active_record/connection_adapters/makara_abstract_adapter'
require 'active_record/connection_adapters/proxysql_adapter'

if ActiveRecord::VERSION::MAJOR >= 4

  module ActiveRecord
    module ConnectionHandling
      def makara_proxysql_connection(config)
        ActiveRecord::ConnectionAdapters::MakaraProxySQLAdapter.new(config)
      end
    end
  end

else

  module ActiveRecord
    class Base
      def self.makara_proxysql_connection(config)
        ActiveRecord::ConnectionAdapters::MakaraProxySQLAdapter.new(config)
      end
    end
  end

end

module ActiveRecord
  module ConnectionAdapters
    class MakaraProxySQLAdapter < ActiveRecord::ConnectionAdapters::MakaraAbstractAdapter

      class << self
        def visitor_for(*args)
          ActiveRecord::ConnectionAdapters::ProxySQLAdapter.visitor_for(*args)
        end
      end

      protected

      def active_record_connection_for(config)
        ::ActiveRecord::Base.proxysql_connection(config)
      end

    end
  end
end
