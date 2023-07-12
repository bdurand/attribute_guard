# frozen_string_literal: true

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" if File.exist?(ENV["BUNDLE_GEMFILE"])

begin
  require "simplecov"
  SimpleCov.start do
    add_filter ["/spec/", "/app/", "/config/", "/db/"]
  end
rescue LoadError
end

Bundler.require(:default, :test)

require "active_record"

require_relative "../lib/attribute_guard"

ActiveRecord::Base.establish_connection("adapter" => "sqlite3", "database" => ":memory:")

class BaseModel < ActiveRecord::Base
  unless table_exists?
    connection.create_table(table_name) do |t|
      t.column :type, :string, null: false
      t.column :name, :string, null: false
      t.column :value, :integer, null: true
    end

    self.abstract_class = true

    before_save do
      self.type = self.class.name
    end
  end

  include AttributeGuard
end

class TestModel < BaseModel
  lock_attributes :name
end

class TestModelSubclass < TestModel
  lock_attributes :value, error: "Value cannot be changed message"
end

class UnlockedModel < BaseModel
end
