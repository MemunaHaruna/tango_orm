require "active_support/inflector"
require "tango_orm/db"

module TangoOrm
  class Model
    def self.table_name
      self.name.downcase.pluralize
    end

    def self.db
      @db ||= DB.new
    end

    def self.columns
      sql = <<-SQL
            SELECT *
            FROM information_schema.columns
            WHERE table_name = '#{table_name}';
          SQL
      names = db.execute{|connection| connection.exec(sql) }
      names.map{|name| name["column_name"].to_sym}
    end

    def initialize(options = {})
      options = options.merge(id: nil)
      options.each {|name, value| instance_variable_set("@#{name}", value)}
    end

    def method_missing(method_name, *arguments, &block)
      attribute_getters = self.class.columns
      attribute_setters = attribute_getters.map{|getter| "#{getter}=".to_sym}

      if attribute_getters.include?(method_name)
        instance_variable_get("@#{method_name}")
      elsif attribute_setters.include?(method_name)
        name = method_name.to_s.delete("=").to_sym
        instance_variable_set("@#{name}", arguments[0])
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      getters = self.class.columns
      setters = getters.map{|getter| "#{getter}=".to_sym}

      getters.include?(method_name) || setters.include?(method_name) || super
    end

    def self.create_table(options)
      formatted_options = {}
      options.each do |key, value|
        formatted_options[key] = value.upcase.gsub(/[,_]/, " ")
      end

      column_config = ""
      formatted_options.each do |key, value|
        line = "#{key.to_s} #{value}, "
        column_config << line
      end

      column_config = column_config.chomp(", ")

      sql = <<-SQL
        CREATE TABLE #{table_name} (
          id SERIAL PRIMARY KEY,
          #{column_config}
          );
        SQL

      db.execute{|connection| connection.exec(sql) }
      puts "Table '#{table_name}' created successfully"
    end

    def self.drop_table
      sql = "DROP TABLE #{table_name}"
      db.execute{|connection| connection.exec(sql) }
      puts "Table '#{table_name}' dropped successfully"
    end

    def save
      db = self.class.db
      db_table = self.class.table_name
      variable_names = attributes.join(", ")
      variable_numbers = (1..attributes.count).map{|i| "$#{i}" }.join(", ")
      variable_values = attributes.map{|var| send(var)}

      sql = <<~SQL
        INSERT INTO #{db_table} (#{variable_names})
        VALUES (#{variable_numbers})
        RETURNING id;
      SQL

      db.execute do |connection|
        connection.exec(sql, variable_values) do |result|
          self.id = result[0]["id"].to_i
        end
      end

      self
    end

    def self.create(options)
      new_song = new(options)
      new_song.save
    end

    def update
      db = self.class.db
      db_table = self.class.table_name
      numbered_var_names = attributes.map.with_index {|attr, i| "#{attr} = $#{i + 1}"}.join(", ")
      variable_values = attributes.map{|var| send(var)} + [self.id]
      id_value = "$#{variable_values.count}"

      sql = <<~SQL
        UPDATE #{db_table}
        SET #{numbered_var_names}
        WHERE id = #{id_value}
        RETURNING *;
      SQL

      db.execute do |connection|
        connection.exec(sql, variable_values) do |result|
          self.class.new_from_db(result[0])
        end
      end
    end

    def self.find_by_id(id)
      sql = "SELECT * FROM #{table_name} WHERE id = $1"

      db.execute do |connection|
        connection.exec(sql, [id]) do |result|
          result.map do |row|
            new_from_db(row)
          end
        end.first
      end
    end

    def self.all
      db.execute do |connection|
        connection.exec("SELECT * FROM #{table_name}") do |result|
          result.map do |row|
            new_from_db(row)
          end
        end
      end
    end

    private

    def attributes
      instance_variables.map{ |var| var.to_s.gsub("@", "") } - ["id"]
    end

    def self.new_from_db(row)
      instance = self.new  # self.new is the same as running Model.new

      row.each do |name, value|
        if name == "id"
          instance.instance_variable_set("@#{name}", value.to_i)
        else
          instance.instance_variable_set("@#{name}", value)
        end
      end
      instance  # return the newly created instance
    end
  end
end
