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
      t.column :foo, :integer, null: true
      t.column :bar, :integer, null: true
      t.column :baz, :integer, null: true
      t.column :bip, :integer, null: true
    end

    self.abstract_class = true

    before_save do
      self.type = self.class.name
    end
  end

  @@logger_output = StringIO.new

  class << self
    def logger_output
      @@logger_output
    end
  end

  self.logger = Logger.new(@@logger_output)

  include AttributeGuard
end

class TestModel < BaseModel
  lock_attributes :name
end

class TestModelSubclass < TestModel
  lock_attributes :value, error: "Value cannot be changed message"
  lock_attributes :foo, :bar, mode: :warn
  lock_attributes :baz, mode: ->(record, attribute) { record.errors.add(attribute, "Custom error") }
  lock_attributes :bip, mode: :strict
end

class UnlockedModel < BaseModel
end

class GenericModel
  include ActiveModel::Model
  include AttributeGuard

  attr_accessor :name, :value

  lock_attributes :name
end
