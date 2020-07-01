require 'active_record/connection_adapters/makara_abstract_adapter'
require 'active_record/connection_adapters/mysql2_adapter'

if ActiveRecord::VERSION::MAJOR >= 4

  module ActiveRecord
    module ConnectionHandling
      def proxysql_makara_connection(config)
        ActiveRecord::ConnectionAdapters::MakaraProxySQLAdapter.new(config)
      end
    end
  end

else

  module ActiveRecord
    class Base
      def self.proxysql_makara_connection(config)
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

      def configure_connection
        puts "Overridden configure_connection"
        @connection.query_options.merge!(as: :array)

        variables = @config.fetch(:variables, {}).stringify_keys

        # By default, MySQL 'where id is null' selects the last inserted id.
        # Turn this off. http://dev.rubyonrails.org/ticket/6778
        variables["sql_auto_is_null"] = 0

        # Increase timeout so the server doesn't disconnect us.
        wait_timeout = self.class.type_cast_config_to_integer(@config[:wait_timeout])
        wait_timeout = 2147483 unless wait_timeout.is_a?(Integer)
        variables["wait_timeout"] = wait_timeout

        # Make MySQL reject illegal values rather than truncating or blanking them, see
        # http://dev.mysql.com/doc/refman/5.0/en/server-sql-mode.html#sqlmode_strict_all_tables
        # If the user has provided another value for sql_mode, don't replace it.
        unless variables.has_key?("sql_mode")
          variables["sql_mode"] = strict_mode? ? "STRICT_ALL_TABLES" : ""
        end

        # NAMES does not have an equals sign, see
        # http://dev.mysql.com/doc/refman/5.0/en/set-statement.html#id944430
        # (trailing comma because variable_assignments will always have content)
        if @config[:encoding]
          encoding = "NAMES #{@config[:encoding]}"
          encoding << " COLLATE #{@config[:collation]}" if @config[:collation]
          encoding << ", "
        end

        # Gather up all of the SET variables...
        variable_assignments = variables.map do |k, v|
          if v == ":default" || v == :default
            "@@SESSION.#{k} = DEFAULT" # Sets the value to the global or compile default
          elsif !v.nil?
            "@@SESSION.#{k} = #{quote(v)}"
          end
          # or else nil; compact to clear nils out
        end.compact.join(", ")

        # The ProxySQL config at /etc/proxysql.cnf keeps multiplexing enabled on queries tagged with /* keep_multiplexing_enabled */
        # Otherwise multiplexing is disabled because it sets the session variables, and the db connections are not shared between processes.
        # https://github.com/sysown/proxysql/wiki/Multiplexing#ad-hoc-enabledisable-of-multiplexing
        @connection.query("SET #{encoding} #{variable_assignments} /* keep_multiplexing_enabled */")
      end


      protected

      def active_record_connection_for(config)
        ::ActiveRecord::Base.mysql2_connection(config)
      end

    end
  end
end
